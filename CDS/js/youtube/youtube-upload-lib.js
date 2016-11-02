var Promise = require('promise');
var fs = require('fs');
var youtubeAuth = require('./youtube-auth.js');
var googleapis = require('googleapis');
var OAuth2 = googleapis.auth.OAuth2;
var dataStore = require('../Datastore');

const YOUTUBE_API_VERSION = 'v3';

function getMetadata(connection) {

    return new Promise((fulfill, reject) => {

        if (!process.env.title) {
            reject(new Error('Cannot upload to youtube: missing a title'));
        }

        if (!process.env.description) {
            reject(new Error('Cannot upload to youtube: missing a description'));
        }

        if (!process.env.category_id) {
            reject(new Error('Cannot upload to youtube: missing a category id'));
        }

        fulfill(dataStore.substituteStrings(connection, [process.env.title, process.env.description, process.env.category_id, process.env.access])
        .then((substitutedStrings) => {
            var title, description, category_id, status;
            [title, description, category_id, status] = substitutedStrings;

            return {
                snippet: {
                    title: title,
                    description: description,
                    categoryId: category_id
                },
                status: { privacyStatus: status ? status : 'private'}
            }
        }));
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
                        fulfill(
                            dataStore.set(connection, 'meta', 'youtube_id', result.id)
                            .then(() => {
                                return result;
                            })
                            .catch((err) => {
                                return result;
                            })
                        );
                     }
                })
           });
        });
    });
}

module.exports = {
    uploadToYoutube: uploadToYoutube,
    getMetadata: getMetadata,
    getYoutubeData: getYoutubeData,
};

