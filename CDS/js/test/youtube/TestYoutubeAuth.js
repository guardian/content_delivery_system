var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

var googleapis = require('googleapis');
var OAuth2 = googleapis.auth.OAuth2;
var AWS = require('aws-sdk');
var Promise = require('promise');
var pem = require('pem');
var fs = require('fs');

process.env.cf_datastore_location='location';
var dataStore = require('../../Datastore.js');
var youtubeAuth = require('../../youtube/youtube-auth');

const CREDENTIALS_PATH = './test/youtube/lib/youtube_credentials.json';
const INVALID_CREDENTIALS_PATH = './test/youtube/lib/invalid_youtube_credentials.json';

describe('youtubeAuth', () => {

    describe('#readP12', () => {
        var stringSubstituteStub, p12Read, writeFile;

        beforeEach(() => {
            stringSubstituteStub = sinon.stub(dataStore, 'substituteStrings', (connection, val) => {
                return new Promise((fulfill) => {
                    fulfill(val);
                });
            });
            p12Read = sinon.stub(pem, 'readPkcs12');
            p12Read.yields(null, {key: 'key'});

            writeFile = sinon.stub(fs, 'writeFileSync');

        });

        afterEach(() => {
            stringSubstituteStub.restore();
            writeFile.restore();
            p12Read.restore();
        });

        it('should raise exception if private key or passphase is missing', () => {

            return assert.isRejected(youtubeAuth.readP12(), 'Cannot upload to youtube: private key and passphrase required');
        });

        it('should save key in a file if private key and passphare are set', () => {

            process.env.private_key = 'key';
            process.env.passphrase = 'passphrase';

            return youtubeAuth.readP12()
            .then(() => {
                sinon.assert.calledOnce(p12Read);
                sinon.assert.calledOnce(stringSubstituteStub);
                sinon.assert.calledOnce(writeFile);
                sinon.assert.calledWith(writeFile, './privatekey.pem', 'key', 'utf8');
                return;
            });

        });
    });

    describe('#getCredentials', () => {
        var fsStub;
        var stringSubstituteStub;

        before(() => {
            fsStub = sinon.stub(fs, 'readFileSync').returns('{"credentials": "credentials"}');
        });

        after(() => {
            fsStub.restore();
        });

        beforeEach(() => {
            stringSubstituteStub = sinon.stub(dataStore, 'substituteString', (connection, val) => {
                return new Promise((fulfill) => {
                    fulfill(val);
                });
            });
        });

        afterEach(() => {
            stringSubstituteStub.restore();
        });

        it('should raise an exception if no path to credentials file provided', () => {

            return assert.isRejected(youtubeAuth.getCredentials(), 'Cannot upload to youtube: client secrets file path not provided');
        });

        it('should fetch credentials when path is provided', () => {

            process.env.client_secrets = CREDENTIALS_PATH;

            assert.eventually.deepEqual(youtubeAuth.getCredentials(), { credentials: 'credentials'});
            return;
        });
    });

    describe('getAuthClient', () => {

        var p12Stub;

        beforeEach(() => {
            p12Stub = sinon.stub(youtubeAuth, 'readP12');
        });

        afterEach(() => {
            p12Stub.restore();
        });

        it('should raise an error if client_id is missing', () => {
            var credentialsStub = sinon.stub(youtubeAuth, 'getCredentials');
            var promise = new Promise((fulfill, reject) => {
                fulfill({
                    client_secret: 'secret',
                    web: {client_email: 'client_email' }
                });
            });

            credentialsStub.returns(promise);


            assert.isRejected(youtubeAuth.getAuthClient(), 'Credentials file is missing client_id property');

            credentialsStub.restore();
            return;

        });

        it('should raise an error if client_secret is missing', () => {
            var credentialsStub = sinon.stub(youtubeAuth, 'getCredentials');
            var promise = new Promise((fulfill, reject) => {
                fulfill({
                    client_id: 'id',
                    web: {client_email: 'client_email' }
                });
            });

            credentialsStub.returns(promise);

            assert.isRejected(youtubeAuth.getAuthClient(), 'Credentials file is missing a client_secret property');
            credentialsStub.restore();
            return;

        });

        it('should raise an error if web property is missing', () => {
            var credentialsStub = sinon.stub(youtubeAuth, 'getCredentials');
            var promise = new Promise((fulfill, reject) => {
                fulfill({
                    client_id: 'id',
                    client_secret: 'secret',
                });
            });

            credentialsStub.returns(promise);

            assert.isRejected(youtubeAuth.getAuthClient(), 'Credentials file is missing client_email property');
            credentialsStub.restore();
            return;

        });

        it('should raise an error if client_email is missing', () => {
            var credentialsStub = sinon.stub(youtubeAuth, 'getCredentials');
            var promise = new Promise((fulfill, reject) => {
                fulfill({
                    client_id: 'id',
                    client_secret: 'secret',
                    web: {}
                });
            });

            credentialsStub.returns(promise);

            assert.isRejected(youtubeAuth.getAuthClient(), 'Credentials file is missing client_email property');
            credentialsStub.restore();
            return;

        });

        it('should return auth client when credentials file is found', () => {

            var credentialsStub = sinon.stub(youtubeAuth, 'getCredentials');
            var promise = new Promise((fulfill, reject) => {
                fulfill({
                    client_id: 'id',
                    client_secret: 'secret',
                    web: {client_email: 'client_email' }
                });
            });

            credentialsStub.returns(promise);

            process.env.client_secrets = CREDENTIALS_PATH;
            var setCredentialsSpy = sinon.spy(OAuth2.prototype, 'setCredentials');

            var jwtStub = sinon.stub(googleapis.auth.JWT.prototype, 'authorize');
            jwtStub.yields(null, {access_token: 'token'});


            return youtubeAuth.getAuthClient()
            .then((client) => {

                assert(credentialsStub.calledOnce);
                assert(p12Stub.calledOnce);
                assert(jwtStub.calledOnce);
                assert(setCredentialsSpy.calledOnce);
                const authArg = setCredentialsSpy.lastCall.args[0];
                assert.equal(authArg.access_token, 'token');
                credentialsStub.restore();
                setCredentialsSpy.restore();
                jwtStub.restore();
                return;

            });
        });

    });
});

