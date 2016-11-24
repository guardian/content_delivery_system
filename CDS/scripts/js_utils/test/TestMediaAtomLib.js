var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

process.env.cf_datastore_location = "location";
var datastore = require('../Datastore');
var atomLib = require('../media-atom-lib');
var hmac = require('../hmac');
var reqwest = require('reqwest');
var nock = require('nock');


describe('mediaAtomLib', () => {

    var datastoreStub, hmacStub, stringsStub, datastoreSetStub;
    const URL_BASE = 'https://www.base';
    const TOKEN = 'token';
    const dateRegex = /^[A-Z][a-z]{2}\,\s\d{2}\s[A-Z][a-z]{2}\s\d{4}\s\d{2}:\d{2}:\d{2}\sGMT$/i;

    beforeEach(() => {

        datastoreSetStub = sinon.stub(datastore, 'set');

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

    afterEach(() => {
        hmacStub.restore();
        datastoreStub.restore();
        stringsStub.restore();
        datastoreSetStub.restore();
        delete process.env.url_base;
        delete process.env.atom_id;
    });

    describe('#fetchMetadata', () => {
        const URI = '/api2/atom/atom_id';

        it('should raise an exception if url base is missing', () => {
            return assert.isRejected(atomLib.fetchMetadata(), 'Cannot add assets to media atom: missing url base');

        });

        it('should raise an exception if url base is missing', () => {
            process.env.url_base = URL_BASE;

            return assert.isRejected(atomLib.fetchMetadata(), 'Cannot add assets to media atom: missing atom id');
        });

        it('should fetch atom from media atom maker', () => {
            process.env.url_base = URL_BASE;
            process.env.atom_id = 'atom_id';

            var reqwest = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .get(URI)
                .reply(200, {
                    data: {
                        title: 'title',
                        description: 'description'
                    }
                });

            return atomLib.fetchMetadata()
            .then(response => {
                assert.ok(response.data);
                assert.equal(response.data.title, 'title');
                assert.equal(response.data.description, 'description');
                sinon.assert.calledOnce(hmacStub);
                sinon.assert.calledOnce(stringsStub);
                sinon.assert.calledThrice(datastoreSetStub);
                return;
            });
        });
    });

    describe('#postAsset', () => {
        const URI = '/api2/atom/atom_id/asset';

        it('should raise an exception if url base is missing', () => {
            return assert.isRejected(atomLib.postAsset(), 'Cannot add assets to media atom: missing url base');

        });

        it('should raise an exception if url base is missing', () => {
            process.env.url_base = URL_BASE;

            return assert.isRejected(atomLib.postAsset(), 'Cannot add assets to media atom: missing atom id');
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
                .put(URI, {
                    uri: 'https://www.youtube.com/watch?v=youtube_id'
                })
                .reply(200, {
                    ok: 'ok'
                });

            return atomLib.postAsset()
            .then(response => {
                assert.ok(response.ok);
                sinon.assert.calledOnce(datastoreStub);
                sinon.assert.calledOnce(hmacStub);
                sinon.assert.calledOnce(stringsStub);
                return;
            });
        });
        it('should allow for customising the asset url base', () => {
            process.env.url_base = URL_BASE;
            process.env.atom_id = 'atom_id';
            process.env.asset_url = 'https://www.customised.com/'

            var reqwest = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .put(URI, {
                    uri: process.env.asset_url + 'youtube_id'
                })
                .reply(200, {
                    ok: 'ok'
                });

            return atomLib.postAsset()
            .then(response => {
                assert.ok(response.ok);
                return;
            });
        });
    });
});
