var Promise = require('promise');
var fs = require('fs');
var youtubeAuth = require('./youtube-auth.js');
var googleapis = require('googleapis');
var OAuth2 = googleapis.auth.OAuth2;
var dataStore = require('../Datastore');

const YOUTUBE_API_VERSION = 'v3';

function getMetadata(connection) {

    return dataStore.substituteString(connection, process.env.access)
    .then(status => {
        return Promise.all([dataStore.get(connection, 'meta', 'atom_title'), dataStore.get(connection, 'meta', 'atom_description'), dataStore.get(connection, 'meta', 'category_id')])
        .then(results => {
            let title, description, categoryId
            [title, description, categoryId] = results.map(result => result.value);

            return {
                snippet: {
                    title: title,
                    description: description,
                    categoryId: categoryId
                },
                status: { privacyStatus: status ? status : 'private'}
            };
        });
    });
}

function getYoutubeData(connection) {
    return this.getMetadata(connection)
    .then((metadata) => {
        const mediaPath = process.env.cf_media_file;

        if (!process.env.cf_media_file) {
            throw new Error('Cannot upload to youtube: missing media file path. Make sure that media has been specified in the route');
        }

        if (process.env.owner_channel) {
            if (!process.env.owner_account) {
                throw new Error('Cannot upload to youtube: missing account owner');
            }
        }

        return dataStore.substituteStrings(connection, [process.env.cf_media_file, process.env.owner_channel, process.env.owner_account])
        .then((substitutedStrings) => {
            var mediaPath, ownerChannel, ownerAccount;
            [mediaPath, ownerChannel, ownerAccount] = substitutedStrings;

            var youtubeData = {
                'part': 'snippet,status',
                'resource': metadata,
                'media': {body: fs.createReadStream(mediaPath)},
                'uploadType': 'multipart'
            };

            if (ownerChannel) {
                youtubeData.onBehalfOfContentOwner = ownerAccount;
                youtubeData.onBehalfOfContentOwnerChannel = ownerChannel;
            }

            return youtubeData;
        });
    });
}

function addPosterImageIfExists(connection, videoId, youtubeClient, account) {
    return dataStore.get(connection, 'meta', 'poster_image')
    .then(file => {

        if (file.value) {

          if (!account) {
            return new Promise((fulfill, reject) => { reject( new Error('could not add a poster image: missing account owner') )});
          }
          return  new Promise((fulfill, reject) => {
            youtubeClient.thumbnails.set({ videoId: videoId, onBehalfOfContentOwner: account, media: {body: fs.createReadStream(file.value)}}, (err, result) => {
                  if (err) reject(err);
                  else fulfill(result);
            });
          });
        }
        return new Promise(fulfill => {fulfill()});
      });
}

function uploadToYoutube(connection) {

    return youtubeAuth.getAuthClient(connection)
    .then((oauth2) => {
        var youtubeClient = googleapis.youtube({version: YOUTUBE_API_VERSION, auth: oauth2});
        return this.getYoutubeData(connection)
        .then((youtubeData) => {

            return new Promise((fulfill, reject) => {
                youtubeClient.videos.insert(youtubeData, (err, result) => {
                if (err) reject(err);
                if (result) {
                    fulfill(addPosterImageIfExists(connection, result.id, youtubeClient, youtubeData.onBehalfOfContentOwner)
                    .then(() => {
                        return dataStore.set(connection, 'meta', 'youtube_id', result.id)
                        .then(() => {
                          return result;
                        })
                        .catch((err) => {
                            return result;
                        })
                    })
                    )
                }
            });
        });
    });
    });
}

module.exports = {
  uploadToYoutube: uploadToYoutube,
  getMetadata: getMetadata,
    getYoutubeData: getYoutubeData,
};
