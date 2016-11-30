var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

process.env.cf_datastore_location = "location";
var datastore = require('../Datastore');
var atomLib = require('../media-atom-lib');
var hmac = require('../hmac');
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

    describe('#makeAssetActive', () => {
      let pollingIntervalStub;

      beforeEach(() => {
        pollingIntervalStub = sinon.stub(atomLib, 'setPollingInterval', (counter) => {

          const INTERVAL = 1;
          const MAX_TRIES = 2;

          if (counter > MAX_TRIES) {
            return new Promise((fulfill, reject) => {
              reject(new Error('Cannot add asset to youtube, video encoding took too long'));
            });
          }
          return new Promise(fulfill => {
            setTimeout(fulfill, INTERVAL)
          });
        });
      });

      afterEach(() =>{
        pollingIntervalStub.restore();
      });


      it('should raise an exception if url base is missing', () => {
        return assert.isRejected(atomLib.makeAssetActive(), 'Cannot add assets to media atom: missing url base');

      });

      it('should raise an exception if atom id is missing', () => {
        process.env.url_base = URL_BASE;

        return assert.isRejected(atomLib.makeAssetActive(), 'Cannot add assets to media atom: missing atom id');
      });

      it('should mark an asset as active', () => {
        process.env.url_base = URL_BASE;
        process.env.atom_id = 'atom_id';
        const URI = '/api2/atom/atom_id/asset-active';

        var scope = nock(URL_BASE, {
          'X-Gu-Tools-HMAC-Date': dateRegex,
          'X-Gu-Tools-HMAC-Token': TOKEN,
          'X-Gu-Tools-Service-Name': 'content_delivery_system'
        })
        .post(URI, {
          youtubeId: 'youtube_id'})
          .reply(200)

        return atomLib.makeAssetActive()
          .then(response => {
            assert.ok(response.status);
            sinon.assert.calledOnce(hmacStub);
            sinon.assert.calledOnce(stringsStub);

            sinon.assert.calledOnce(datastoreStub);
            return;
          });
      });

      it('should poll the api until succesful', () => {
        process.env.url_base = URL_BASE;
        process.env.atom_id = 'atom_id';
        const URI = '/api2/atom/atom_id/asset-active';

        var scope = nock(URL_BASE, {
          'X-Gu-Tools-HMAC-Date': dateRegex,
          'X-Gu-Tools-HMAC-Token': TOKEN,
          'X-Gu-Tools-Service-Name': 'content_delivery_system'
        })
        .post(URI, {
          youtubeId: 'youtube_id'})
          .reply(400, 'Asset encoding in process')
        .post(URI, {
          youtubeId: 'youtube_id'})
          .reply(200)

        return atomLib.makeAssetActive()
          .then(response => {
            assert.ok(response.status);
            sinon.assert.calledTwice(hmacStub);
            sinon.assert.calledOnce(stringsStub);

            sinon.assert.calledOnce(datastoreStub);
            return;
          });
      });
    });

    describe('#fetchMetadata', () => {
        const URI = '/api2/atoms/atom_id';
        let dataStoreMultiStub;

        beforeEach(() => {
          dataStoreMultiStub = sinon.stub(datastore, 'setMulti').returns(new Promise(fulfill => {fulfill()}));
        });

        afterEach(() => {
          dataStoreMultiStub.restore();
        });

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

            var scope = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .get(URI)
                .reply(200, {
                  title: 'title',
                  description: 'description',
                  tags: ['key','words']
                });

            return atomLib.fetchMetadata()
            .then(response => {
                assert.equal(response.title, 'title');
                assert.equal(response.description, 'description');
                sinon.assert.calledOnce(hmacStub);
                sinon.assert.calledOnce(stringsStub);
                sinon.assert.calledOnce(dataStoreMultiStub);
                const keywordArgs = dataStoreMultiStub.getCall(0).args;
                assert.equal(keywordArgs[2].keywords, 'key,words');

                return;
            });
        });
        it('should pick the biggest possible image', () => {
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
                  posterImage: {
                    assets: [
                      {
                        size: 1,
                        file: 'small'
                      },
                      {
                        size: 3000000,
                        file: 'big'
                      },
                      {
                        size: 10000,
                        file: 'best'
                      }
                    ]
                  }
                });

            return atomLib.fetchMetadata()
            .then(response => {
                sinon.assert.calledOnce(dataStoreMultiStub);
                sinon.assert.calledWith(dataStoreMultiStub, undefined, 'meta', {'poster_image': 'best'});
                return;
            });
        });
    });

    describe('#postAsset', () => {
        const URI = '/api2/atoms/atom_id/assets';

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

            var scope = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .post(URI, {
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

            var scope = nock(URL_BASE, {
                    reqheaders: {
                        'X-Gu-Tools-HMAC-Date': dateRegex,
                        'X-Gu-Tools-HMAC-Token': TOKEN,
                        'X-Gu-Tools-Service-Name': 'content_delivery_system'
                    }})
                .post(URI, {
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
