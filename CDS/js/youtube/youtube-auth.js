var googleapis = require('googleapis');
var OAuth2 = googleapis.auth.OAuth2;
var fs = require('fs');
var Promise = require('promise');
var pem = require('pem');
var Q = require('q');

const SECRET_KEY_FILE_PATH = './privatekey.pem';
const SCOPES = [
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.readonly",
    "https://www.googleapis.com/auth/youtube.upload"
];

function getCredentials() {

    return new Promise((fulfill, reject) => {

        const credentialsFile = process.env.client_secrets;
        if (!credentialsFile) {
            reject (new Error('Cannot upload to youtube: client secrets file path not provided'));
        }

        try {
            fulfill(JSON.parse(fs.readFileSync(credentialsFile,'utf8')));
        } catch (ex) {
            reject(new Error('Cannot read credentials : ' + ex));
        }
    });
}

function readP12() {
    return new Promise((fulfill, reject) => {

        if (!process.env.private_key || !process.env.passphrase) {
            reject (new Error('Cannot upload to youtube: private key and passphrase required'));
        }

        pem.readPkcs12(process.env.private_key, {p12Password: process.env.passphrase}, (err, result) => {
            if (err) reject(err);
            if (result) {
                fs.writeFileSync(SECRET_KEY_FILE_PATH, result.key, 'utf8');
                fulfill();
            }
        });
    })
}

function getAuthClient() {

    return Q.all([this.getCredentials(), this.readP12()])
    .spread((credentials) => {

        if (!credentials.client_id) {
            throw new Error('Credentials file is missing client_id property');
        }

        if (!credentials.client_secret) {
            throw new Error('Credentials file is missing a client_secret property');
        }

        if (!credentials.web || !credentials.web.client_email) {
            throw new Error('Credentials file is missing a web.client_email property');
        }

        var oauth2 = new OAuth2(credentials.client_id, credentials.client_secret);

        var jwt = new googleapis.auth.JWT(
            credentials.web.client_email,
            SECRET_KEY_FILE_PATH,
            null,
            SCOPES
        );

        return new Promise((fulfill, reject) => {

            jwt.authorize((err, result) => {
                if (err) err
                else {
                    oauth2.setCredentials({
                        access_token: result.access_token
                    });

                    fulfill(oauth2);
                }
            });
        });
    });
}

module.exports = {
    getAuthClient: getAuthClient,
    getCredentials: getCredentials,
    readP12: readP12
};

