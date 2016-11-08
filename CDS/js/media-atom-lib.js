var reqwest = require('reqwest');
var Promise = require('promise');
var datastore = require('./Datastore');
var hmac = require('./hmac');

const urlBase = process.env.url_base;
const assetPath = '/api2/atom/:id/asset';
const metadataPath = '/api2/atom/:id/metadata';

function checkExistenceAndSubstitute(connection, variables) {
    const missingIndex = variables.findIndex(variable => {
        return !variable.value
    });

    if (missingIndex !== -1) {
        return new Promise((fulfill, reject) => {
            reject(new Error(variables[missingIndex].error));
        });
    }

    return datastore.substituteStrings(connection, variables.map(variable => variable.value));
};


function fetchMetadata(connection) {

    const requiredVariables = [{value: process.env.url_base, error: 'Cannot add assets to media atom: missing url base'}, {value: process.env.atom_id, error: 'Cannot add assets to media atom: missing atom id'}];

    let urlBase, atomId;
    return checkExistenceAndSubstitute(connection, requiredVariables)
    .then(substitutedStrings => {
        [urlBase, atomId] = substitutedStrings;

        const date = (new Date()).toUTCString();
        const uri = metadataPath.replace(/:id/, atomId);
        const url = urlBase + uri;

        return hmac.makeHMACToken(connection, date, uri)
        .then(token => {
            return reqwest({
                url: url,
                method: 'GET',
                contentType: 'application/json',
                headers: {
                    'X-Gu-Tools-HMAC-Date': date,
                    'X-Gu-Tools-HMAC-Token': token,
                    'X-Gu-Tools-Service-Name': 'content_delivery_system'
                }
            })
            .then(response => {
                var title = 'title';
                var description = 'description';
                return Promise.all([datastore.set(connection, 'meta', 'atom_title', title), datastore.set(connection, 'meta', 'atom_description', description)])
                .then(() => {
                    return response;
                });
            });
        });
    });
};


function postAsset(connection) {

    const requiredVariables = [{value: process.env.url_base, error: 'Cannot add assets to media atom: missing url base'}, {value: process.env.atom_id, error: 'Cannot add assets to media atom: missing atom id'}];

    let urlBase, atomId;
    return checkExistenceAndSubstitute(connection, requiredVariables)
    .then(substitutedStrings => {
        [urlBase, atomId] = substitutedStrings;

        return datastore.get(connection, 'meta', 'youtube_url')
        .then(result => {
            const date = (new Date()).toUTCString();

            const youtubeUrl = result.value;

            const data = { uri: youtubeUrl };
            const uri = assetPath.replace(/:id/, atomId);
            const url = urlBase + uri;

            return hmac.makeHMACToken(connection, date, uri)
            .then(token => {

                return reqwest({
                    url: url,
                    method: 'PUT',
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
    postAsset: postAsset,
    fetchMetadata: fetchMetadata
};

