const Promise = require('promise');
const fs = require('fs');
const youtubeAuth = require('./youtube-auth.js');
const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const dataStore = require('../Datastore');
const https = require('https');

const YOUTUBE_API_VERSION = 'v3';

function getPosterImageDownloadDir() {
    const defaultPosterImageDir = '/tmp';

    return !! process.env.poster_image_dir && process.env.poster_image_dir || defaultPosterImageDir;
}

function getMetadata(connection) {

    return dataStore.substituteString(connection, process.env.access)
    .then(status => {
        return Promise.all([
            dataStore.get(connection, 'meta', 'atom_title'),
            dataStore.get(connection, 'meta', 'atom_description'),
            dataStore.get(connection, 'meta', 'atom_category'),
            dataStore.get(connection, 'meta', 'keywords')
        ]).then(results => {
            const dsMeta = results.reduce((hash,elem)=>{
                hash[elem['key']]=elem['value'];
                return hash;
            }, {});

            const rtn = {
                snippet: {
                    title: dsMeta.atom_title,
                    description: dsMeta.atom_description,
                    categoryId: parseInt(dsMeta.atom_category)
                },
                status: { privacyStatus: status ? status : 'private'}
            };
            if(dsMeta.keywords){
                rtn.snippet.tags = dsMeta.keywords.split(',');
            }
            return rtn;
        });
    });
}

function getYoutubeData(connection) {
    return this.getMetadata(connection)
    .then((metadata) => {
        console.log("getYoutubeData: got " + JSON.stringify(metadata));
        const mediaPath = process.env.cf_media_file;

        if (!process.env.cf_media_file) {
            throw new Error('Cannot upload to youtube: missing media file path. Make sure that media has been specified in the route');
        }

        if (process.env.owner_channel) {
            if (!process.env.owner_account) {
                throw new Error('Cannot upload to youtube: missing account owner');
            }
        }

        console.log("About to upload '" + process.env.cf_media_file + "' to youtube...");

        return dataStore.substituteStrings(connection, [process.env.cf_media_file, process.env.owner_channel, process.env.owner_account])
        .then((substitutedStrings) => {
            var mediaPath, ownerChannel, ownerAccount;
            [mediaPath, ownerChannel, ownerAccount] = substitutedStrings;

            var youtubeData = {
                'part': 'snippet,status',
                'resource': metadata,
                'media': {body: fs.createReadStream(process.env.cf_media_file)},
                'uploadType': 'multipart'
            };

            if (ownerChannel) {
                youtubeData.onBehalfOfContentOwner = ownerAccount;
                youtubeData.onBehalfOfContentOwnerChannel = ownerChannel;
            }

            return youtubeData;
        });
    });
}

function isSecureUrl(maybeSecure) {
    return maybeSecure.startsWith('https://');
}

function downloadPosterImage(url, dest) {
    return new Promise((resolve, reject) => {
        if (! isSecureUrl(url)) {
            reject('No https poster image in metadata');
        }

        const file = fs.createWriteStream(dest);

        https.get(url, (response) => {
            response.pipe(file);
            file.on('finish', () => file.close(resolve(dest)));
        }).on('error', (err) => {
            fs.unlink(dest);
            reject(err);
        });
    });
}

function addPosterImageIfExists(connection, videoId, youtubeClient, account) {
    return new Promise((resolve, reject) => {
        if (! account) {
            reject(new Error('could not add a poster image: missing account owner'));
        }

        dataStore.get(connection, 'meta', 'poster_image').then(posterImage => {
            downloadPosterImage(posterImage.value, `${getPosterImageDownloadDir()}/${videoId}`)
                .then(filename => {
                    const payload = {
                        videoId: videoId,
                        onBehalfOfContentOwner: account,
                        media: {
                            body: fs.createReadStream(filename)
                        }
                    };

                    youtubeClient.thumbnails.set(payload, (err, result) => {
                        fs.unlink(filename);

                        if (err) {
                            console.log(payload);
                            console.log("ERROR: Unable to set poster image onto video: " + err);
                            reject(err);
                        } else {
                            console.log("+SUCCESS: Added poster image onto video");
                            resolve(result);
                        }
                    });
                })
                .catch(err => reject(err));
        });
    });
}

function uploadToYoutube(connection) {
    return new Promise((resolve, reject) => {
        console.log("DEBUG: getting auth client");
        youtubeAuth.getAuthClient(connection).then(authClient => {
            console.log("DEBUG: got auth client.  Getting youtube client for version " + YOUTUBE_API_VERSION);
            const ytClient = googleapis.youtube({version: YOUTUBE_API_VERSION, auth: authClient});

            this.getYoutubeData(connection).then(ytData => {
                console.log("DEBUG: got youtube data " + JSON.stringify(ytData));
                console.log("Attempting to insert video...");
                ytClient.videos.insert(ytData, (err, result) => {
                    if (err) {
                        console.error("ERROR: unable to insert YT video: " + err);
                        reject(err);
                    } else {
                        console.log("Video added successfully.  Adding poster frame...");
                        addPosterImageIfExists(connection, result.id, ytClient, ytData.onBehalfOfContentOwner)
                            .then(() => {
                                dataStore.set(connection, 'meta', 'youtube_id', result.id)
                                    .then(() => {
                                        resolve(result);
                                    })
                                    .catch(error => {
                                        console.error("-ERROR: " + error);   //this shows an error returned by the datastore when attemting to set
                                        reject(error)
                                    });
                            })
                            .catch(err => {
                                console.error("-ERROR: " + err);
                                reject(err);
                            });
                    }
                });
            });
        }).catch(err=> {
            console.error("ERROR: " + JSON.stringify(err));
            reject(err);
        });
    });
}

module.exports = {
  uploadToYoutube: uploadToYoutube,
  getMetadata: getMetadata,
  getYoutubeData: getYoutubeData,
};
