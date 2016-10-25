const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const fs = require('fs');
const AWS = require('aws-sdk');
const Promise = require('promise');
AWS.config.region = 'eu-west-1';


YOUTUBE_API_VERSION = 'v3';
CREDENTIALS_OBJECT_KEY = 's3-credentials.json';

function getCredentials() {

    return new Promise(function(fulfill, reject) {
        const bucket = process.env.credentials_bucket;
        const filePath = process.env.client_secrets;

        if (!filePath && !bucket) {
            reject (new Error('Cannot upload to youtube: no filepath or bucket name for credentials provided'));
        }


        if (bucket) {
            const s3 = new AWS.S3();
            return s3.getObject({
                Bucket: bucket,
                Key: CREDENTIALS_OBJECT_KEY
            }, function(error, data) {
                if (error) reject(error);
                else {
                    try {
                        fulfill(JSON.parse(data.Body.toString()));
                    } catch (ex) {
                        reject(new Error('Invalid json in credentials bucket'));
                    }
                }
            });
        }

        else if (filePath) {

            try {
                fulfill(JSON.parse(fs.readFileSync(filePath,'utf8')));
            } catch (ex) {
                reject(new Error('Cannot parse file ', filePath));
            }

        }
    });
}


function getAuthClient() {

    return getCredentials()
    .then(function (credentials) {

        const tokenExpiry = (credentials.token_expiry - Date.now()).ceil

        var oauth2Client = new OAuth2(credentials.client_id, credentials.client_secret);
        oauth2Client.setCredentials({
            access_token: null,
            expiry_date: tokenExpiry,
            refresh_token: credentials.refresh_token
        });

        return oauth2Client;
    });
}

module.exports = {
    getAuthClient: getAuthClient,
    getCredentials: getCredentials
};

