const fs = require('fs');

const Logger = require('../logger');

class YoutubeVideoUpload {
    constructor ({cdsModel, config, youtubeAuthedClient}) {
        this.cdsModel = cdsModel;
        this.config = config;
        this.youtubeAuthedClient = youtubeAuthedClient;
        this.mediaFilepath = this.config.cfMediaFile;
        this.contentOwner = this.config.ownerAccount;
    }

    upload () {
        return new Promise((resolve, reject) => {
            this.cdsModel.getData().then(cdsModelData => {
                this._uploadVideo(cdsModelData)
                    .then(result => resolve(result))
                    .catch(e => reject(e));
            });
        });
    }

    _uploadVideo (cdsModelData) {
        return new Promise((resolve, reject) => {
            const snippetStatus = this._getSnippetStatus(cdsModelData);

            const ytData = {
                part: 'snippet,status',
                resource: snippetStatus,
                uploadType: 'multipart',
                media: {
                    body: fs.createReadStream(this.mediaFilepath)
                },
                onBehalfOfContentOwner: this.contentOwner,
                onBehalfOfContentOwnerChannel: cdsModelData.channelId
            };

            Logger.info(`uploading video to youtube channel ${cdsModelData.channelId}`);
            this.youtubeAuthedClient.videos.insert(ytData, (err, result) => {
                if (err) {
                    reject(err);
                }
                else {
                    this.cdsModel.saveYoutubeId(result.id).then(() => {
                        Logger.info(`video uploaded ${result.id}`);
                        resolve(result);
                    });
                }
            });
        });
    }

    _getSnippetStatus (cdsModelData) {
        const ytData = {
            snippet: {
                title: cdsModelData.title,
                categoryId: cdsModelData.category
            },
            status: {
                privacyStatus: cdsModelData.privacyStatus.toLowerCase()
            }
        };

        if (cdsModelData.tags) {
            ytData.snippet.tags = cdsModelData.tags;
        }

        return ytData;
    }
}

module.exports = YoutubeVideoUpload;