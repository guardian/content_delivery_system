const assert = require('assert');
const path = require('path');
const fs = require('fs');
const DatabaseInit = require('../../datastore/db-init');
const Database = require('../../datastore/db');

const dbPath = path.join(__dirname, '../data/test.db');

function safeRemoveFile(path) {
    fs.exists(path, (exists) => {
        if (exists) {
            fs.unlink(path);
        }
    })
}

describe('DataStore database', () => {
    beforeEach((done) => {
        safeRemoveFile(dbPath);
        new DatabaseInit(dbPath).then(() => done());
    });

    afterEach(() => {
        safeRemoveFile(dbPath);
    });

    it('should return an `undefined` value when no data exists', (done) => {
        const db = new Database('test', dbPath);

        db.getOne('meta', 'name').then(actual => {

            const expected = {
                value: undefined,
                type: 'meta',
                key: 'name'
            };

            assert.deepEqual(actual, expected);
            done();
        }).catch(e => console.log(e))
    });

    it('should be able to insert a meta record', (done) => {
        const db = new Database('test', dbPath);

        db.setOne('meta', 'name', 'MrTest').then(() => {
            db.getOne('meta', 'name').then(actual => {
                const expected = {
                    type: 'meta',
                    key: 'name',
                    value: 'MrTest'
                };
                assert.deepEqual(actual, expected);
                done();
            });
        });
    });

    it('should be able to insert multiple records', (done) => {
       const db = new Database('test', dbPath);

       db.setMany('meta', {name: 'foo', age: 'bar'}).then(() => {
           Promise.all([db.getOne('meta', 'name'), db.getOne('meta', 'age')]).then(actual => {
              const expected = [
                  { type: 'meta', key: 'name', value: 'foo' },
                  { type: 'meta', key: 'age', value: 'bar' }
              ];

              assert.deepEqual(actual, expected);
              done();
           }).catch(e => console.log(e));
       });
    });

    it('should throw an exception when an unexpected type is used', (done) => {
        const db = new Database('test', dbPath);

        // couldn't get assert.throws to work
        try {
            db.getOne('foo', 'bar');
        }
        catch (e) {
            assert.equal(e, 'type must be meta, media, tracks');
            done();
        }
    })
});