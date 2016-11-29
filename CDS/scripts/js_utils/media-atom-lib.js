var Promise = require('promise');
var datastore = require('./Datastore');
var HMACRequest = require('./HMACRequest');

const urlBase = process.env.url_base;
const assetPath = '/api2/atoms/:id/assets';
const metadataPath = '/api2/atoms/:id'
const activeAssetPath = '/api2/atom/:id/asset-active';
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

        return HMACRequest.makeRequest(connection, date, uri, urlBase, 'GET')
        .then(response => {

          const title = response.title;
          const description = response.description;
          const categoryId = response.youtubeCategoryId;

          let propertiesToSet = {};
          if (title) {
            propertiesToSet.atom_title = title;
          }

          if (description) {
            propertiesToSet.atom_description = description;
          }

          if (categoryId) {
            propertiesToSet.atom_category = categoryId
          }

          if (response.posterImage) {
            const sortedAssets = response.posterImage.assets.sort((asset1, asset2) => {
              return asset2.size - asset1.size;
            });

            const bestAsset = sortedAssets.find(asset => { return asset.size <= MAX_FILE_SIZE; }).file;

            propertiesToSet.poster_image = bestAsset;
          }

          return datastore.setMulti(connection, 'meta', propertiesToSet)
          .then(() => {
              return response;
          });
        });
    });
};

function makeAssetActive(connection) {

  counter = 1;

  const environmentVariables = [{value: process.env.url_base, error: 'Cannot add assets to media atom: missing url base'}, {value: process.env.atom_id, error: 'Cannot add assets to media atom: missing atom id'}];

  let atomId, youtubeId, urlBase;

  return Promise.all([checkExistenceAndSubstitute(connection, environmentVariables), datastore.get(connection, 'meta', 'youtube_id')])
  .then(results => {

    [urlBase, atomId] = results[0];
    youtubeId = results[1].value;

    const data = { youtubeId: youtubeId };
    const uri = activeAssetPath.replace(/:id/, atomId);

    function makeActive() {

      const date = (new Date()).toUTCString();
      return HMACRequest.makeRequest(connection, date, uri, urlBase, 'POST', data)
      .then(response => {
        return response;
      })
      .catch(error => {
        if (error.status === 400 && error.response === 'Asset encoding in process') {
          return this.setPollingInterval(counter)
          .then(() => {
            counter++;
            return makeActive.bind(this)();
          });
        } else {
          throw new Error(error);
        }
      });
    }

    return makeActive.bind(this)();
  });
};

function setPollingInterval(counter) {

    const INTERVAL = 21000;
    const MAX_TRIES = 100;

    if (counter > MAX_TRIES) {
      return new Promise((fulfill, reject) => {
        reject(new Error('Cannot add asset to youtube, video encoding took too long'));
      });
    }
    return new Promise(fulfill => {
      setTimeout(fulfill, INTERVAL)
    });
}

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

            return HMACRequest.makeRequest(connection, date, uri, urlBase, 'POST', data)

        });
    });
}

module.exports = {
    postAsset: postAsset,
    fetchMetadata: fetchMetadata,
    makeAssetActive: makeAssetActive,
    setPollingInterval: setPollingInterval
};
