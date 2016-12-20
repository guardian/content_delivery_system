const fs = require('fs');

class YoutubeVideoUpload {
    constructor (cdsModel, configObj, youtubeAuthedClient) {
        const requiredConfig = ['cf_media_file', 'owner_account'];

        requiredConfig.forEach(c => {
            if (! Object.keys(configObj.config).includes(c)) {
                throw `Invalid Config. Missing ${c}`;
            }
        });

        this.cdsModel = cdsModel;
        this.configObj = configObj;
        this.youtubeAuthedClient = youtubeAuthedClient;
        this.mediaFilepath = this.configObj.config.cf_media_file;
        this.contentOwner = this.configObj.config.owner_account;
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

            this.youtubeAuthedClient.videos.insert(ytData, (err, result) => {
                if (err) {
                    reject(err);
                }
                else {
                    this.cdsModel.saveYoutubeId(result.id).then(() => {
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