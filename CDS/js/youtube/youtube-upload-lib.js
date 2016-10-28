var Promise = require('promise');
var fs = require('fs');
var youtubeAuth = require('./youtube-auth.js');
var googleapis = require('googleapis');
var OAuth2 = googleapis.auth.OAuth2;
var dataStore = require('../DataStore.js');

const YOUTUBE_API_VERSION = 'v3';

function getMetadata() {
    var title, description, category, status;

    if (!process.env.title) {
        throw new Error('Cannot upload to youtube: missing a title');
    }

    title = process.env.title;

    if (!process.env.description) {
        throw new Error('Cannot upload to youtube: missing a description');
    }

    description = process.env.description;

    if (!process.env.category_id) {
        throw new Error('Cannot upload to youtube: missing a category id');
    }

    category = process.env.category_id;

    status = process.env.access ? process.env.access : 'private';


    return {
        snippet: {
            title: title,
            description: description,
            categoryId: category
        },
        status: { privacyStatus: status }
    }
}

function getYoutubeData() {
    const metadata = getMetadata();
    const mediaPath = process.env.cnf_media_file;

    if (!mediaPath) {
        throw new Error('Cannot upload to youtube: missing media file path');
    }

    if (process.env.owner_channel) {
        if (!process.env.owner_account) {
            throw new Error('Cannot upload to youtube: missing account owner');
        }
    }

    var youtubeData = {
         'part': 'snippet,status',
         'resource': metadata,
         'media': {body: fs.readFileSync(mediaPath)},
         'uploadType': 'multipart',
         'onBehalfOfContentOwner': process.env.owner_account,
         'onBehalfOfContentOwnerChannel': process.env.owner_channel
    };
    return youtubeData;

}

function saveResultToDataStore(result) {
    var connection = new dataStore.Connection("YoutubeDataStore");
    return dataStore.set(connection, 'meta', 'youtube_id', result.id);
}

function uploadToYoutube() {

    return youtubeAuth.getAuthClient()
    .then((oauth2) => {

       var youtubeClient = googleapis.youtube({version: YOUTUBE_API_VERSION, auth: oauth2});
       const youtubeData = this.getYoutubeData();

       return new Promise((fulfill, reject) => {
            youtubeClient.videos.insert(youtubeData, (err, result) => {
                if (err) reject(err);
                if (result) {
                    this.saveResultToDataStore(result)
                    .then(() => {
                        fulfill(result);
                    })
                    .catch((err) => {
                        fulfill(result);
                    });
                 }
            })
       });
    });
}

module.exports = {
    uploadToYoutube: uploadToYoutube,
    getMetadata: getMetadata,
    getYoutubeData: getYoutubeData,
    saveResultToDataStore: saveResultToDataStore
};

