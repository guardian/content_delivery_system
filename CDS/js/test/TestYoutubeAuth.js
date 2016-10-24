const assert = require('assert');
const sinon = require('sinon');
const googleapis = require('googleapis');
const OAuth2 = googleapis.auth.OAuth2;
const fs = require('fs');

const youtubeAuth = require('../youtube-auth');

describe('youtubeAuth', function() {

    it('should raise an error if no credentials', function(done) {

        assert.throws(youtubeAuth, Error, 'Cannot upload to youtube: no filepath for credentials provided');
        done();
    });

    it('should return auth client when credentials file is found', function(done) {

        process.env.client_secrets = './test/lib/youtube_credentials.json';
        const setCredentialsSpy = sinon.spy(OAuth2.prototype, 'setCredentials');

        youtubeAuth();

        assert(setCredentialsSpy.calledOnce);

        const authCredentials = setCredentialsSpy.lastCall.args[0];
        assert.equal(authCredentials.access_token, null);
        assert.equal(authCredentials.refresh_token, 'refresh');
        //TODO: check for token refresh

        done();
    });

});

