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

        it('should raise an exception if url base is missing', () => {
            return assert.isRejected(asset.postAsset(), 'Cannot add assets to media atom maker: missing url base');

        });

        it('should post asset to atom maker', () => {

            const URL_BASE = 'https://www.base';
            const URI = '/api2/atom/atom_id/asset';
            const TOKEN = 'token';
            const dateRegex = /^[A-Z][a-z]{2}\,\s\d{2}\s[A-Z][a-z]{2}\s\d{4}\s\d{2}:\d{2}:\d{2}\sGMT$/i;
            process.env.url_base = URL_BASE;

            var connectionStub = sinon.createStubInstance(datastore.Connection);

            var datastoreStub = sinon.stub(datastore, 'get', (connection, type, key) => {
                return new Promise((fulfill) => {
                    fulfill({ value: key });
                });
            });

            var hmacStub = sinon.stub(hmac, 'makeHMACToken').returns(
                new Promise(fulfill => {
                    fulfill(TOKEN);
                })
            );

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
                sinon.assert.calledTwice(datastoreStub);
                sinon.assert.calledOnce(hmacStub);
                return;
            });

        });

    });
});
