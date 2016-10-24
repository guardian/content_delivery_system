const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const fs = require('fs');

YOUTUBE_API_VERSION = 'v3'

module.exports = function () {

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

