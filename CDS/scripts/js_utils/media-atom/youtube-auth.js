const googleapis = require('googleapis');
const pem = require('pem');
const fs = require('fs');

const OAuth2 = googleapis.auth.OAuth2;
const JWT = googleapis.auth.JWT;
const YT = googleapis.youtube;

class YoutubeAuth {
    constructor ({config}) {
        this.config = config;

        this.privateKey = this.config.privateKey;
        this.passphrase = this.config.passphrase;
        this.clientSecretsFilepath = this.config.clientSecrets;

        this.youtubeApiVersion = 'v3';
    }

    _ensureCanReadPrivateKey () {
        return new Promise((resolve, reject) => {
            pem.readPkcs12(this.privateKey, {
                p12Password: this.passphrase
            }, (err) => err ? reject(err) : resolve());
        });
    }

    _readCredentialsFile () {
        return new Promise((resolve, reject) => {
            fs.exists(this.clientSecretsFilepath, (maybeExists) => {
                if (! maybeExists) {
                    reject(`Cannot find credentials file. ${this.clientSecretsFilepath}`);
                }

                const fileContents = fs.readFileSync(this.clientSecretsFilepath, 'utf8');
                const json = JSON.parse(fileContents);

                const requiredKeys = [ 'client_id', 'client_secret', 'web' ];

                requiredKeys.forEach(i => {
                    if (! Object.keys(json).includes(i)) {
                        reject(`Invalid credentials file. Missing ${i}`);
                    }
                });

                if (! json.web.client_email) {
                    reject('Invalid credentials file. Missing web.client_email');
                }

                resolve(json);
            });
        });
    }

    getAuthedYoutubeClient () {
        const scopes = [
            "https://www.googleapis.com/auth/youtube.force-ssl",
            "https://www.googleapis.com/auth/youtube",
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/youtube.upload"
        ];

        return new Promise((resolve, reject) => {
            Promise.all([this._ensureCanReadPrivateKey(), this._readCredentialsFile()]).then(res => {
                // remove the `undefined` returned from `_ensureCanReadPrivateKey`
                const credentials = res.filter(Boolean)[0];

                const oauth2 = new OAuth2(credentials.client_id, credentials.client_secret);
                const jwt = new JWT(credentials.web.client_email, this.privateKey, null, scopes);

                jwt.authorize((err, result) => {
                    if (err) {
                        reject(err);
                    }

                    oauth2.setCredentials({
                        access_token: result.access_token
                    });

                    const ytClient = YT({version: this.youtubeApiVersion, auth: oauth2});

                    resolve(ytClient);
                });
            });
        });

    }
}

module.exports = YoutubeAuth;