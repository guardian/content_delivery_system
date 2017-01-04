class MediaAtomModel {
    constructor ({apiResponse}) {
        this._data = apiResponse;

        this.requiredFieldsFromAtom = ['channelId', 'title', 'youtubeCategoryId'];

        this.maxPosterImageFileSize = 2 * 1000 * 1000; // 2MB
    }

    validate () {
        return new Promise ((resolve, reject) => {
            const missingFields = this.requiredFieldsFromAtom.reduce((missing, field) => {
                if (! Object.keys(this._data).includes(field)) {
                    missing.push(field);
                }
                return missing;
            }, []);

            if (missingFields.length === 0) {
                resolve(this);
            } else {
                reject(missingFields);
            }
        });
    }

    get id () {
        return this._data.id;
    }

    get channelId () {
        return this._data.channelId;
    }

    get title () {
        return this._data.title;
    }

    get categoryId () {
        return this._data.youtubeCategoryId;
    }

    get tags () {
        return !! this._data.tags && this._data.tags.join(',');
    }

    get posterImage () {
        if (this._data.posterImage) {
            const posterCandidates = this._data.posterImage.assets
                .sort((p1, p2) => { return p2.size - p1.size; })
                .filter(p => p.size < this.maxPosterImageFileSize);

            if (posterCandidates.length > 0) {
                return posterCandidates[0].file;
            }
        }
    }

    get privacyStatus () {
        return this._data.privacyStatus;
    }
}

module.exports = MediaAtomModel;
