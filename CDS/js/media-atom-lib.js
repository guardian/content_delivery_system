var reqwest = require('reqwest');
var Promise = require('promise');
var datastore = require('./Datastore');
var hmac = require('./hmac');

const urlBase = process.env.url_base;
const assetPath = '/api2/atom/:id/asset';
const metadataPath = '/api2/atom/:id'
const youtubePrefix = 'https://www.youtube.com/watch?v='

function checkExistenceAndSubstitute(connection, variables) {
    const missingIndex = variables.findIndex(variable => {
        return !variable.value && variable.error;
    });

    if (missingIndex !== -1) {
        return new Promise((fulfill, reject) => {
            reject(new Error(variables[missingIndex].error));
        });
    }

    return datastore.substituteStrings(connection,
        variables.reduce((substitutions, variable) => {
          if (variable.value) {
            substitutions.push(variable.value);
          }
          return substitutions;
        }, [])
    );
};


function fetchMetadata(connection) {

    const environmentVariables = [{value: process.env.url_base, error: 'Cannot add assets to media atom: missing url base'}, {value: process.env.atom_id, error: 'Cannot add assets to media atom: missing atom id'}];

    let urlBase, atomId;
    return checkExistenceAndSubstitute(connection, environmentVariables)
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
                const title = response.data.title;
                const description = response.data.description;
                return Promise.all([datastore.set(connection, 'meta', 'atom_title', title), datastore.set(connection, 'meta', 'atom_description', description)])
                .then(() => {
                    return response;
                });
            });
        });
    });
};


function postAsset(connection) {

    const environmentVariables = [
      {value: process.env.url_base, error: 'Cannot add assets to media atom: missing url base'},
      {value: process.env.atom_id, error: 'Cannot add assets to media atom: missing atom id'},
      {value: process.env.asset_url, error: null}
    ];

    let urlBase, atomId, assetBase;

    return checkExistenceAndSubstitute(connection, environmentVariables)
    .then(substitutedStrings => {

        if (substitutedStrings.length === 2) {
          [urlBase, atomId] = substitutedStrings;
          assetBase = youtubePrefix;
        } else if (substitutedStrings.length === 3) {
          [urlBase, atomId, assetBase] = substitutedStrings;
        }

        return datastore.get(connection, 'meta', 'youtube_id')
        .then(result => {
            const date = (new Date()).toUTCString();

            const youtubeUrl = assetBase + result.value;

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

