const Logger = require('../logger');
const MediaAtomModel = require('./model/media-atom-model');

class MediaAtom {
    constructor (cdsModel, config, hmacRequest, apiPollDuration = 5 * 60 * 1000, apiPollInterval = 60 * 1000) {
        this.cdsModel = cdsModel;
        this.config = config;
        this.hmacRequest = hmacRequest;

        this.atomApiPaths = {
            asset: `/api2/atoms/:id/assets`,
            metadata: '/api2/atoms/:id',
            activateAsset: '/api2/atom/:id/asset-active'
        };

        this.apiPollDuration = apiPollDuration;
        this.apiPollInterval = apiPollInterval;
    }

    _getUrl (path, atomId) {
        return `${this.config.atomUrl}${path}`.replace(/:id/, atomId);
    }

    fetchAndSaveMetadata () {
        return new Promise ((resolve, reject) => {
            this.cdsModel.getData().then(cdsModel => {
                if (! cdsModel.atomId) {
                    reject('Failed to get atomId from database');
                }

                const url = this._getUrl(this.atomApiPaths.metadata, cdsModel.atomId);

                this.hmacRequest.get(url).then(response => {
                    const model = new MediaAtomModel(response);

                    model.validate().then(atomModel => {
                        this.cdsModel.saveAtomModel(atomModel).then(() => {
                            Logger.info('saved atom to database');
                            resolve(response);
                        });
                    }).catch(missingFields => {
                        reject(`Invalid response from Atom API. Missing ${missingFields.join(',')}`);
                    });
                });
            });
        });
    }

    _httpPoll (url, data, timeoutMessage) {
        const self = this; // to avoid `.bind(this)`

        const endTime = Number(new Date()) + this.apiPollDuration;

        function checkCondition (resolve, reject) {
            self.hmacRequest.put(url, data)
                .then(response => resolve(response))
                .catch(() => {
                    if (Number(new Date()) < endTime) {
                        Logger.info(`video hasn't finished encoding. Retrying.`);
                        setTimeout(checkCondition, self.apiPollInterval, resolve, reject);
                    } else {
                        Logger.info(`we've waited for ${self.apiPollDuration / 1000} seconds and youtube hasn't encoded the video yet.`);
                        reject(timeoutMessage);
                    }
                });
        }

        return new Promise(checkCondition);
    }

    activateAsset () {
        const timeoutMessage = 'Cannot activate youtube asset, video encoding took too long';

        return new Promise((resolve, reject) => {
            this.cdsModel.getData().then(cdsModel => {
                if (! cdsModel.youtubeId) {
                    reject('Failed to get youtubeId from database');
                }

                const data = { youtubeId: cdsModel.youtubeId };
                const url = this._getUrl(this.atomApiPaths.activateAsset, cdsModel.atomId);

                this._httpPoll(url, data, timeoutMessage)
                    .then(response => {
                        Logger.info('activated asset');
                        resolve(response);
                    })
                    .catch(e => reject(e));
            });
        });
    }

    addAsset () {
        return new Promise((resolve, reject) => {
            this.cdsModel.getData().then(cdsModel => {
               if (! cdsModel.youtubeId) {
                   reject('Failed to get youtubeId from database');
               }

                const data = { uri: `https://www.youtube.com/watch?v=${cdsModel.youtubeId}` };
                const url = this._getUrl(this.atomApiPaths.asset, cdsModel.atomId);

                this.hmacRequest.post(url, data).then(response => {
                    Logger.info(`added asset ${data.uri} to atom ${cdsModel.atomId}`);
                    resolve(response);
                }).catch(e => reject(e));
            });
        });
    }
}

module.exports = MediaAtom;
