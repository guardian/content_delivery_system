class MediaAtom {
    constructor (database, configObj, hmacRequest, apiPollDuration = 5 * 60 * 1000, apiPollInterval = 60 * 1000) {
        const requiredConfig = ['url_base', 'atom_id'];

        requiredConfig.forEach(c => {
            if (! Object.keys(configObj.config).includes(c)) {
                throw `Invalid Config. Missing ${c}`;
            }
        });

        this.database = database;
        this.configObj = configObj;
        this.hmacRequest = hmacRequest;

        this.atomId = this.configObj.config.atom_id;
        this.atomApiDomain = this.configObj.config.url_base;

        this.atomApiPaths = {
            asset: `/api2/atoms/:id/assets`,
            metadata: '/api2/atoms/:id',
            activateAsset: '/api2/atom/:id/asset-active'
        };

        this.maxPosterImageFileSize = 2 * 1000 * 1000; // 2MB
        this.apiPollDuration = apiPollDuration;
        this.apiPollInterval = apiPollInterval;
    }

    _getUrl (path) {
        return `${this.atomApiDomain}${path}`.replace(/:id/, this.atomId);
    }

    fetchMetadata () {
        const url = this._getUrl(this.atomApiPaths.metadata);
        const requiredMetadataFromAtom = [ 'channelId', 'title', 'youtubeCategoryId' ];

        return new Promise ((resolve, reject) => {
            this.hmacRequest.get(url).then(response => {
                requiredMetadataFromAtom.forEach(i => {
                    if (! Object.keys(response).includes(i)) {
                        reject(`Incomplete metadata from media atom. Missing ${i}`);
                    }
                });

                const atomMetadata = {
                    atom_channelId: response.channelId,
                    atom_title: response.title,
                    atom_ytCategory: response.youtubeCategoryId
                };

                if (response.description) {
                    atomMetadata.atom_description = response.description;
                }

                if (response.tags) {
                    atomMetadata.atom_keywords = response.tags.join(',');
                }

                if (response.posterImage) {
                    const posterCandidates = response.posterImage.assets
                        .sort((p1, p2) => { return p2.size - p1.size; })
                        .filter(p => p.size < this.maxPosterImageFileSize);

                    if (posterCandidates.length > 0) {
                        atomMetadata.atom_posterImage = posterCandidates[0].file;
                    }
                }

                this.database.setMany('meta', atomMetadata).then(() => resolve(response));
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
                        setTimeout(checkCondition, self.apiPollInterval, resolve, reject);
                    } else {
                        reject(timeoutMessage);
                    }
                });
        }

        return new Promise(checkCondition);
    }

    activateAsset () {
        const timeoutMessage = 'Cannot add asset to youtube, video encoding took too long';

        return new Promise((resolve, reject) => {
            this.database.getOne('meta', 'atom_youtubeId').then(res => {

                if (! res.value) {
                    reject('Failed to get atom_youtubeId from database');
                }

                const data = { youtubeId: res.value };
                const url = this._getUrl(this.atomApiPaths.activateAsset);

                this._httpPoll(url, data, timeoutMessage)
                    .then(response => resolve(response))
                    .catch(e => reject(e));
            });
        });
    }

    addAsset () {
        return this.database.getOne('meta', 'atom_youtubeId').then(res => {
            if (! res.value) {
                reject('Failed to get atom_youtubeId from database');
            }

            const data = { uri: `https://www.youtube.com/watch?v=${res.value}` };
            const url = this._getUrl(this.atomApiPaths.asset);

            return this.hmacRequest.post(url, data);
        });
    }
}

module.exports = MediaAtom;