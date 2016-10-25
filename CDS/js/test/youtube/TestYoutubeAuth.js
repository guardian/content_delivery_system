const assert = require('assert');
const sinon = require('sinon');
const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const fs = require('fs');
const AWS = require('aws-sdk');
const Promise = require('promise');

const youtubeAuth = require('../../youtube/youtube-auth');

const CREDENTIALS_PATH = './test/youtube/lib/youtube_credentials.json';

describe('youtubeAuth', function() {

    describe('getCredentials', function() {


        it('should raise an error if credentials path and bucket name is missing', function(done) {

            assert.throws(function() {
                youtubeAuth.getAuthClient();
                done();
            });
        });

        it('should fetch credentials from credentials file if no bucket specified', function() {

            process.env.client_secrets = CREDENTIALS_PATH;

            return youtubeAuth.getCredentials()
            .then(function(credentials) {
                assert.equal(credentials.refresh_token, 'refresh');
                assert.equal(credentials.access_token, null);
                assert.equal(credentials.client_secret, 'secret');
                assert.equal(credentials.client_id, 'id');
                assert.equal(credentials.token_expiry, 2);

                delete process.env.client_secrets;

            });
        });

        it('should fetch credentials from bucket when bucket name is specified', function() {

            process.env.credentials_bucket = 'bucket';

           var getObject = AWS.S3.prototype.getObject = sinon.stub();
           const buffer = new Buffer('"credentials"');

           getObject.yields(null, {'Body': buffer});

            return youtubeAuth.getCredentials()
            .then(function(credentials) {
                assert.equal(credentials, 'credentials');
                delete process.env.credentials_bucket;
            });
        });
    });

    describe('getAuthClient', function() {


        it('should return auth client when credentials file is found', function(done) {

            process.env.client_secrets = CREDENTIALS_PATH;
            const setCredentialsSpy = sinon.spy(OAuth2.prototype, 'setCredentials');

            return youtubeAuth.getAuthClient().done(function(credentials) {

                assert(setCredentialsSpy.calledOnce);

                const authCredentials = setCredentialsSpy.lastCall.args[0];
                assert.equal(authCredentials.access_token, null);
                assert.equal(authCredentials.refresh_token, 'refresh');
                //TODO: check for token refresh

                done();
            });
        });

    });
});

