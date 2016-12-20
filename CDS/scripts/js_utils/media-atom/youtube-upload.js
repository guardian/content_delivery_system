const fs = require('fs');
const path = require('path');
const https = require('https');

class YoutubeUpload {
    constructor (cdsModelData, database, configObj, youtubeAuthedClient) {
        const requiredConfig = ['cf_media_file', 'owner_account'];

        requiredConfig.forEach(c => {
            if (! Object.keys(configObj.config).includes(c)) {
                throw `Invalid Config. Missing ${c}`;
            }
        });

        this.cdsModelData = cdsModelData;
        this.database = database;
        this.configObj = configObj;
        this.youtubeAuthedClient = youtubeAuthedClient;
        this.mediaFilepath = this.configObj.config.cf_media_file;
        this.contentOwner = this.configObj.config.owner_account;
        this.posterImageDownloadDir = this.configObj.config.poster_image_dir || '/tmp';
    }

    upload () {
        return new Promise((resolve, reject) => {
            this._uploadVideo().then(result => {
                this._setPosterImageIfExists(result.id)
                    .then(resolve(result))
                    .catch(e => reject(e));
            }).catch(e => reject(e));
        });
    }

    _uploadVideo () {
        return new Promise((resolve, reject) => {
            const snippetStatus = this._getSnippetStatus();

            const ytData = {
                part: 'snippet,status',
                resource: snippetStatus,
                uploadType: 'multipart',
                media: {
                    body: fs.createReadStream(this.mediaFilepath)
                },
                onBehalfOfContentOwner: this.contentOwner,
                onBehalfOfContentOwnerChannel: this.cdsModelData.channelId
            };

            this.youtubeAuthedClient.videos.insert(ytData, (err, result) => {
                if (err) {
                    reject(err);
                }
                else {
                    this.database.setOne('meta', 'atom_youtubeId', result.id).then(() => {
                        resolve(result);
                    });
                }
           });
        });
    }

    _setPosterImageIfExists (videoId) {
       const posterImageUrl = this.cdsModelData.posterImage;

       this._downloadPosterImage(posterImageUrl, path.join(this.posterImageDownloadDir, videoId)).then(filename => {
           const payload = {
               videoId: videoId,
               onBehalfOfContentOwner: this.contentOwner,
               media: {
                   body: fs.createReadStream(filename)
               }
           };

           this.youtubeAuthedClient.thumbnails.set(payload, (err, result) => {
               fs.unlink(filename);

               if (err) {
                   reject(err);
               }

               resolve(result);
           });
        }).catch(e => reject(e));
    }

    _downloadPosterImage (url, dest) {
        return new Promise((resolve, reject) => {
            if (! url.startsWith('https://')) {
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
        })
    }

    _getSnippetStatus () {
        const ytData = {
            snippet: {
                title: this.cdsModelData.title,
                categoryId: this.cdsModelData.category
            },
            status: {
                privacyStatus: this.cdsModelData.privacyStatus.toLowerCase()
            }
        };

        if (this.cdsModelData.tags) {
            ytData.snippet.tags = this.cdsModelData.tags;
        }

        return ytData;
    }
}

module.exports = YoutubeUpload;