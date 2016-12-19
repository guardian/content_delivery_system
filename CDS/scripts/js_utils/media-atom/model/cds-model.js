class CdsModel {
    constructor (database) {
        this.database = database;
    }

    getData () {
        return Promise.all([
            this.database.getOne('meta', 'gnm_master_mediaatom_atomid'), // field name defined in Pluto
            this.database.getOne('meta', 'itemId'), // field name defined in Pluto
            this.database.getOne('meta', 'atom_channelId'),
            this.database.getOne('meta', 'atom_title'),
            this.database.getOne('meta', 'atom_ytCategory'),
            this.database.getOne('meta', 'atom_privacyStatus'),
            this.database.getOne('meta', 'atom_tags'),
            this.database.getOne('meta', 'atom_posterImage'),
            this.database.getOne('meta', 'atom_youtubeId')

        ]).then(data => {
           const [atomId, plutoId, channelId, title, category, privacyStatus, tags, posterImage, youtubeId] = data.map(d => d.value);

           return  {
               atomId: atomId,
               plutoId: plutoId,
               channelId: channelId,
               title: title,
               category: category,
               privacyStatus: privacyStatus,
               tags: tags,
               posterImage: posterImage,
               youtubeId: youtubeId
           };
        });
    }

    saveAtomModel (mediaAtomModel) {
        const metadata = {
            atom_channelId: mediaAtomModel.channelId,
            atom_title: mediaAtomModel.title,
            atom_ytCategory: mediaAtomModel.categoryId,
            atom_privacyStatus: mediaAtomModel.privacyStatus || 'Unlisted'
        };

        if (mediaAtomModel.tags) {
            metadata.atom_tags = mediaAtomModel.tags;
        }

        if (mediaAtomModel.posterImage) {
            metadata.atom_posterImage = mediaAtomModel.posterImage;
        }

        return this.database.setMany('meta', metadata);
    }
}

module.exports = CdsModel;