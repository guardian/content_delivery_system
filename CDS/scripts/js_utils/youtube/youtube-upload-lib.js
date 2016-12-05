const Promise = require('promise');
const fs = require('fs');
const youtubeAuth = require('./youtube-auth.js');
const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const dataStore = require('../Datastore');
const https = require('https');

const YOUTUBE_API_VERSION = 'v3';

function getMetadata(connection) {

    return dataStore.substituteString(connection, process.env.access)
    .then(status => {
        return Promise.all([dataStore.get(connection, 'meta', 'atom_title'), dataStore.get(connection, 'meta', 'atom_description'), dataStore.get(connection, 'meta', 'atom_category'), dataStore.get(connection, 'meta', 'keywords')])
        .then(results => {
            let title, description, categoryId, keywords;
            [title, description, categoryId, keywords] = results.map(result => result.value);

            return {
                snippet: {
                    title: title,
                    description: description,
                    categoryId: parseInt(categoryId),
                    tags: keywords.split(',')
                },
                status: { privacyStatus: status ? status : 'private'}
            };
        });
    });
}

function getYoutubeData(connection) {
    return this.getMetadata(connection)
    .then((metadata) => {
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
            fs.unlink(file);
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
            downloadPosterImage(posterImage.value, `/tmp/${videoId}.jpg`).then(filename => {
                const payload = {
                    videoId: videoId,
                    onBehalfOfContentOwner: account,
                    media: {
                        body: fs.createReadStream(filename)
                    }
                };

                youtubeClient.thumbnails.set(payload, (err, result) => err ? reject(err) : resolve(result));
            }).catch(err => {
                reject(err);
            });
        });
    });
}

function uploadToYoutube(connection) {

    return youtubeAuth.getAuthClient(connection)
    .then((oauth2) => {
        var youtubeClient = googleapis.youtube({version: YOUTUBE_API_VERSION, auth: oauth2});
        return this.getYoutubeData(connection)
        .then((youtubeData) => {
            console.log("youtubeData:");
            console.log(youtubeData);
            return new Promise((fulfill, reject) => {
                youtubeClient.videos.insert(youtubeData, (err, result) => {
                    if (err) reject(err);
                    if (result) {
                        console.log("media has been uploaded to youtube. Uploading poster image");
                        fulfill(addPosterImageIfExists(connection, result.id, youtubeClient, youtubeData.onBehalfOfContentOwner)
                        .then(() => {
                            return dataStore.set(connection, 'meta', 'youtube_id', result.id)
                            .then(() => {
                              return result;
                            })
                            .catch((err) => {
                                return result;
                            })
                        })
                        )
                    }
                });
            });
        });
    });
}

module.exports = {
  uploadToYoutube: uploadToYoutube,
  getMetadata: getMetadata,
  getYoutubeData: getYoutubeData,
};
