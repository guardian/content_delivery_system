var reqwest = require('reqwest');
var Promise = require('promise');
var datastore = require('./Datastore');
var hmac = require('./hmac');

const urlBase = process.env.url_base;
const uriBase = '/api2/atom/:id/asset';

function postAsset() {

    if (!process.env.url_base) {
        return new Promise((fulfill, reject) => {
            reject(new Error('Cannot add assets to media atom maker: missing url base'))
        });
    }

    var connection = new datastore.Connection('AddAtomMakerAssets');

    return datastore.substituteString(connection, process.env.url_base)
    .then(urlBase => {

        return Promise.all([datastore.get(connection, 'meta', 'youtube_url'), datastore.get(connection, 'meta', 'atom_id')])
        .then(results => {
            const date = (new Date()).toUTCString();

            const youtubeUrl = results[0].value;

            const data = { uri: youtubeUrl };
            const atomId = results[1].value;
            const uri = uriBase.replace(/:id/, atomId);
            const url = urlBase + uri;

            return hmac.makeHMACToken(connection, date, uri)
            .then(token => {

                return reqwest({
                    url: url,
                    method: 'POST',
                    contentType: 'application/json',
                    headers: {
                        'X-Gu-Tools-HMAC-Date': date,
                        'X-Gu-Tools-HMAC-Token': token,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    },
                    data: JSON.stringify(data)
                });
            });
        })
    });
}

module.exports = {
    postAsset: postAsset
};

