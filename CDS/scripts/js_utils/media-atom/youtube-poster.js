const fs = require('fs');
const path = require('path');
const https = require('https');

const Logger = require('../logger');

class YoutubePosterUpload {
    constructor (cdsModel, configObj, youtubeAuthedClient) {
        this.cdsModel = cdsModel;
        this.configObj = configObj;
        this.youtubeAuthedClient = youtubeAuthedClient;
        this.contentOwner = this.configObj.config.owner_account;
        this.posterImageDownloadDir = this.configObj.config.poster_image_dir || '/tmp';
    }

    upload () {
        return new Promise((resolve, reject) => {
            this.cdsModel.getData().then(cdsModelData => {
                ['posterImage', 'youtubeId'].forEach(required => {
                    if (! Object.keys(cdsModelData).includes(required)) {
                        reject(`No ${required} found in database`);
                    }
                });

                const posterPath = path.join(this.posterImageDownloadDir, cdsModelData.youtubeId);

                this._downloadPosterImage(cdsModelData.posterImage, posterPath).then(filename => {
                    const payload = {
                        videoId: cdsModelData.youtubeId,
                        onBehalfOfContentOwner: this.contentOwner,
                        media: {
                            body: fs.createReadStream(filename)
                        }
                    };

                    Logger.info(`setting poster image to ${cdsModelData.youtubeId}`);
                    this.youtubeAuthedClient.thumbnails.set(payload, (err, result) => {
                        fs.unlink(filename);

                        if (err) {
                            reject(err);
                        }
                        Logger.info(`successfully set poster image to ${cdsModelData.youtubeId}`);
                        resolve(result);
                    });
                }).catch(e => reject(e));
            });
        });
    }

    _downloadPosterImage (url, dest) {
        return new Promise((resolve, reject) => {
            if (! url.startsWith('https://')) {
                reject('No https poster image in metadata');
            }

            const file = fs.createWriteStream(dest);

            https.get(url, (response) => {
                Logger.info(`downloading poster image ${url} to ${dest}`);
                response.pipe(file);
                file.on('finish', () => file.close(resolve(dest)));
            }).on('error', (err) => {
                fs.unlink(file);
                reject(err);
            });
        })
    }
}

module.exports = YoutubePosterUpload;