const assert = require('assert');
const fs = require('fs');
const path = require('path');

const DatabaseInit = require('../../../datastore/db-init');
const Database = require('../../../datastore/db');
const CdsModel = require('../../../media-atom/model/cds-model');

const dbPath = path.join(__dirname, '../../data/test.db');

function safeRemoveFile(path) {
    return new Promise(resolve => {
        if (! fs.existsSync(path)) {
            resolve();
        }
        fs.unlink(path, () => resolve());
    });
}

// TODO these are unit tests. Are they needed? Or are the itegration tests enough?
describe('CdsModel', () => {
    beforeEach((done) => {
        safeRemoveFile(dbPath).then(() => {
            new DatabaseInit(dbPath).then(() => done());
        });
    });

    afterEach((done) => {
        safeRemoveFile(dbPath).then(() => done());
    });

    it('should return an object that always has an atomId', function (done) {
        // this state would occur before `MediaAtom.fetchMetadata` has run.

        const db = new Database('test', dbPath);

        db.setOne('meta', 'gnm_master_mediaatom_atomid', 'AtomOne').then(() => {
            const cdsModel = new CdsModel(db);

            cdsModel.getData().then(actual => {
                const expected = {
                    atomId: 'AtomOne',
                    plutoId: undefined,
                    channelId: undefined,
                    title: undefined,
                    category: undefined,
                    privacyStatus: undefined,
                    tags: undefined,
                    posterImage: undefined,
                    youtubeId: undefined
                };

                assert.deepEqual(actual, expected);
                done();
            });
        });
    });
});