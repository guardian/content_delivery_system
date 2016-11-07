var reqwest = require('reqwest');
var Promise = require('promise');
var datastore = require('./Datastore');
var hmac = require('./hmac');

const urlBase = process.env.url_base;
const path = '/api2/atom/:id/asset';

function postAsset() {

    if (!process.env.url_base) {
        return new Promise((fulfill, reject) => {
            reject(new Error('Cannot add assets to media atom: missing url base'))
        });
    }
    if (!process.env.atom_id) {
        return new Promise((fulfill, reject) => {
            reject(new Error('Cannot add assets to media atom: missing atom id'))
        });
    }

    var connection = new datastore.Connection('AddAAsset');
    datastore.initialiseDb();
    let urlBase, atomId;

    return datastore.substituteStrings(connection, [process.env.url_base, process.env.atom_id])
    .then(substitutedStrings => {
        [urlBase, atomId] = substitutedStrings;

        return datastore.get(connection, 'meta', 'youtube_url')
        .then(result => {
            const date = (new Date()).toUTCString();

            const youtubeUrl = result.value;

            const data = { uri: youtubeUrl };
            const uri = path.replace(/:id/, atomId);
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

