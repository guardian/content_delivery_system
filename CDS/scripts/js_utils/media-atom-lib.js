var reqwest = require('reqwest');
var Promise = require('promise');
var datastore = require('./Datastore');
var hmac = require('./hmac');

const urlBase = process.env.url_base;
const assetPath = '/api2/atoms/:id/assets';
const metadataPath = '/api2/atoms/:id'
const youtubePrefix = 'https://www.youtube.com/watch?v='
const MAX_FILE_SIZE = 2000000;

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
                const title = response.title;
                const description = response.description;
                const categoryId = response.youtubeCategoryId;
                let keywords;

                if (response.tags) {
                    keywords = response.tags.reduce((tagString, tag, index) => {
                        if (index !== 0) {
                            tagString += ',';
                        }
                        tagString += tag;

                        return tagString;
                  }, "");
                }

                let propertiesToSet = [];
                if (title) {
                  propertiesToSet.push({
                    name: 'atom_title',
                    value: title
                  });
                }

                if (description) {
                  propertiesToSet.push({
                    name: 'atom_description',
                    value: description
                  });
                }

                if (categoryId) {
                  propertiesToSet.push({
                    name: 'atom_category',
                    value: description
                  });
                }

                if (keywords) {
                  propertiesToSet.push({
                    name: 'keywords',
                    value: keywords
                  });
                }

                if (response.posterImage) {
                  const sortedAssets = response.posterImage.assets.sort((asset1, asset2) => {
                    return asset2.size - asset1.size;
                  });

                  const bestAsset = sortedAssets.find(asset => { return asset.size <= MAX_FILE_SIZE; }).file;

                  propertiesToSet.push({
                    name: 'poster_image',
                    value: bestAsset
                  });
                }

                return Promise.all(propertiesToSet.map(property => { datastore.set(connection, 'meta', property.name, property.value)}))

                .then(() => { return response });
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

