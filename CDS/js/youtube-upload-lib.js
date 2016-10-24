require('./youtube-env.js');
const Promise = require('promise');
const fs = require('fs');
const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;

YOUTUBE_API_VERSION = 'v3'


function getAuthClient() {

    const filePath = process.env.client_secrets;

    if (!filePath) {
        throw new Error('Cannot upload to youtube: no filepath for credentials provided');
    }
    const credentials = JSON.parse(fs.readFileSync(filePath,'utf8'));
    const tokenExpiry = (credentials.token_expiry - Date.now()).ceil

    var oauth2Client = new OAuth2(credentials.client_id, credentials.client_secret);
    oauth2Client.setCredentials({
        access_token: null,
        expiry_date: tokenExpiry,
        refresh_token: credentials.refresh_token
    });

    return oauth2Client;
}

function getYoutubeClient(authClient) {
    return youtube = googleapis.youtube({version: YOUTUBE_API_VERSION, auth: authClient});
}

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
    const params = {
        uploadType: 'multipart'
    };

    if (!mediaPath) {
        throw new Error('Cannot upload to youtube: missing media file path');
    }

    if (process.env.channel) {
        if (!process.env.owner_account) {
            throw new Error('Cannot upload to youtube: missing account owner');
        }

        params.onBehalfOfContentOwner = process.env.owner_account;
        params.onBehalfOfContentOwnerChannel = process.env.channel;
    }

    var youtubeData = {
         'part': 'snippet,status',
         'resource': metadata,
         'media': {body: fs.readFileSync(mediaPath)},
         'parameters': params
    };
    return youtubeData;

}


function uploadToYoutube() {

    const authClient = getAuthClient();
    const youtubeClient = getYoutubeClient(authClient);
    const youtubeData = getYoutubeData();

    return new Promise(function(fulfill, reject) {

        youtubeClient.videos.insert(youtubeData, function (err, result) {
             if (err) reject(err);
             if (result) fulfill(result);
        })
    });
}

module.exports = {
    uploadToYoutube: uploadToYoutube,
    getAuthClient: getAuthClient,
    getMetadata: getMetadata,
    getYoutubeData: getYoutubeData
};

