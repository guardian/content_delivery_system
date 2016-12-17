const assert = require('assert');
const path = require('path');
const fs = require('fs');
const nock = require('nock');

const Config = require('../../datastore/config');
const Database = require('../../datastore/db');
const DatabaseInit = require('../../datastore/db-init');
const HMACRequest = require('../../media-atom/hmac');

const MediaAtom = require('../../media-atom/media-atom');

const dataDir = path.join(__dirname, '../data');
const dbPath = path.join(__dirname, '../data/test.db');

function safeRemoveFile(path) {
    fs.exists(path, (exists) => { if (exists) { fs.unlink(path); } });
}

const URL_BASE = 'https://no.where';
const ATOM_ID = '123';

describe('MediaAtom', () => {
    beforeEach(function (done) {
        safeRemoveFile(dbPath);
        new DatabaseInit(dbPath).then(function () {
            process.env.shared_secret = 'CanYouKeepASecret';



            process.env.url_base = URL_BASE;
            process.env.atom_id = ATOM_ID;

            this.configObj = new Config(dataDir)
                .withExtraEnvironmentConfig(['shared_secret', 'url_base', 'atom_id']);

            this.hmacRequest = new HMACRequest(this.configObj);
            this.database = new Database('test', dbPath);

            done();
        });
    });

    afterEach(function (done) {
        safeRemoveFile(dbPath);
        done();
    });

    it('should throw an exception if required env config is missing', function (done) {
        try {
            const brokenConfigObj = new Config(dataDir).withExtraEnvironmentConfig(['shared_secret', 'url_base']);
            new MediaAtom(database,  brokenConfigObj, hmacRequest);
        } catch (e) {
            assert.ok(e === 'Invalid Config. Missing atom_id');
            done();
        }
    });

    it('should fetch metadata from media atom but fail when metadata is missing', function (done) {
        const atomApi = `/api2/atoms/${ATOM_ID}`;

        nock(URL_BASE).get(atomApi).reply(200, {
            title: 'foo',
            channelId: 'ChannelOne'
        });

        const mediaAtom = new MediaAtom(database, configObj, hmacRequest);

        mediaAtom.fetchMetadata().catch(e => {
            assert.ok(e.startsWith('Incomplete metadata from media atom. Missing'));
            done();
        })
    });

    it('should fetch metadata from media atom and save it', function (done) {
        const atomApi = `/api2/atoms/${ATOM_ID}`;

        nock(URL_BASE).get(atomApi).reply(200, {
            title: 'foo',
            channelId: 'ChannelOne',
            youtubeCategoryId: '1'
        });

        const mediaAtom = new MediaAtom(database, configObj, hmacRequest);

        mediaAtom.fetchMetadata().then(() => {
           Promise.all([
               database.getOne('meta', 'atom_channelId'),
               database.getOne('meta', 'atom_title'),
               database.getOne('meta', 'atom_ytCategory')
           ]).then(actual => {
              const expected = [
                  { type: 'meta', key: 'atom_channelId', value: 'ChannelOne' },
                  { type: 'meta', key: 'atom_title', value: 'foo' },
                  { type: 'meta', key: 'atom_ytCategory', value: '1' }
              ];

              assert.deepEqual(actual, expected);
              done();
           });
        });
    });

    it('should fetch metadata and save the best poster image under 2MB', function (done) {
        const atomApi = `/api2/atoms/${ATOM_ID}`;

        nock(URL_BASE).get(atomApi).reply(200, {
            title: 'foo',
            channelId: 'ChannelOne',
            youtubeCategoryId: '1',
            posterImage: {
                assets: [{
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/140.jpg",
                    dimensions: { height: 79, width: 140 },
                    size: 7324
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/2000.jpg",
                    dimensions: { height: 1125, width: 2000 },
                    size: 218024
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/500.jpg",
                    dimensions: { height: 281, width: 500 },
                    size: 32557
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/3488.jpg",
                    dimensions: { height: 1962, width: 3488 },
                    size: 460127
                }, {
                    mimeType: "image/jpeg",
                    file: "https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/1000.jpg",
                    dimensions: { height: 563, width: 1000 },
                    size: 85022
                }]
            }
        });

        const mediaAtom = new MediaAtom(database, configObj, hmacRequest);

        mediaAtom.fetchMetadata().then(() => {
            database.getOne('meta', 'atom_posterImage').then(actual => {
                const expected = {
                    type: 'meta',
                    key: 'atom_posterImage',
                    value: 'https://media.guim.co.uk/4d7c1db00237690e268015c5fd09502c66cdfd34/0_64_3488_1962/3488.jpg'
                };

                assert.deepEqual(actual, expected);
                done();
            }).catch(e => console.log(e));
        });
    });

    it('should activate an asset in media atom, but fail when the video encoding takes too long', function (done) {
        const atomApi = `/api2/atom/${ATOM_ID}/asset-active`;

        nock(URL_BASE).put(atomApi).reply(400);

        const pollDuration = 500; // ms
        const pollInterval = 100; // ms

        const mediaAtom = new MediaAtom(database, configObj, hmacRequest, pollDuration, pollInterval);

        database.setOne('meta', 'atom_youtubeId', 'VideoOne').then(() => {
            mediaAtom.activateAsset().catch(e => {
                assert.ok(e === 'Cannot add asset to youtube, video encoding took too long');
                done();
            });
        });
    });

    it('should activate an asset in media atom, polling as it does so', function (done) {
        const atomApi = `/api2/atom/${ATOM_ID}/asset-active`;

        const pollDuration = 1000;
        const pollInterval = 100;

        nock(URL_BASE)
            .put(atomApi).delay(50).reply(400)
            .put(atomApi).delay(50).reply(400)
            .put(atomApi).reply(200, 'asset-activated');

        const mediaAtom = new MediaAtom(database, configObj, hmacRequest, pollDuration, pollInterval);

        database.setOne('meta', 'atom_youtubeId', 'VideoOne').then(() => {
            mediaAtom.activateAsset().then(actual => {
                assert.ok(actual.response === 'asset-activated');
                done();
            }).catch(e => {
                done(new Error(e));
            });
        });
    });

    it('should fail to activate an asset if no atom_youtubeId has not been set in the database', function (done) {
        const mediaAtom = new MediaAtom(database, configObj, hmacRequest);
        mediaAtom.activateAsset().catch(actual => {
            assert.ok(actual === 'Failed to get atom_youtubeId from database');
            done();
        });
    });
});