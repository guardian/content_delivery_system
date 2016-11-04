var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

process.env.cf_datastore_location = "location";
var datastore = require('../Datastore');
var asset = require('../add-asset-lib');
var hmac = require('../hmac');
var reqwest = require('reqwest');
var nock = require('nock');


describe('addAsset', () => {

    describe('#postAsset', () => {
        const URL_BASE = 'https://www.base';
        const URI = '/api2/atom/atom_id/asset';
        const TOKEN = 'token';
        const dateRegex = /^[A-Z][a-z]{2}\,\s\d{2}\s[A-Z][a-z]{2}\s\d{4}\s\d{2}:\d{2}:\d{2}\sGMT$/i;

        var datastoreStub, hmacStub, initialiseStub, stringsStub;

        before(() => {
            sinon.createStubInstance(datastore.Connection);

            initialiseStub = sinon.stub(datastore, 'initialiseDb');

            datastoreStub = sinon.stub(datastore, 'get', (connection, type, key) => {
                return new Promise((fulfill) => {
                    fulfill({ value: key });
                });
            });

            stringsStub = sinon.stub(datastore, 'substituteStrings', (connection, values) => {
                return new Promise((fulfill) => {
                    fulfill(values);
                });
            });

            hmacStub = sinon.stub(hmac, 'makeHMACToken').returns(
                new Promise(fulfill => {
                    fulfill(TOKEN);
                })
            );
        });

        after(() => {
            hmacStub.restore();
            datastoreStub.restore();
            initialiseStub.restore();
        });

        it('should raise an exception if url base is missing', () => {
            return assert.isRejected(asset.postAsset(), 'Cannot add assets to media atom: missing url base');

        });

        it('should raise an exception if url base is missing', () => {
            process.env.url_base = URL_BASE;

            return assert.isRejected(asset.postAsset(), 'Cannot add assets to media atom: missing atom id');

        });

        it('should post asset to atom maker', () => {
            process.env.url_base = URL_BASE;
            process.env.atom_id = 'atom_id';

            var reqwest = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .post(URI, {
                    uri: 'youtube_url'
                })
                .reply(200, {
                    ok: 'ok'
                });

            return asset.postAsset()
            .then(response => {
                assert.ok(response.ok);
                sinon.assert.calledOnce(datastoreStub);
                sinon.assert.calledOnce(hmacStub);
                sinon.assert.calledOnce(stringsStub);
                return;
            });

        });

    });
});
