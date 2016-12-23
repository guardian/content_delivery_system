const assert = require('assert');
const path = require('path');
const Config = require('../../datastore/config');

const goodDataDir = path.join(__dirname, '../data/good');
const badDataDir = path.join(__dirname, '../data/bad');

describe('DataStore Config', () => {
    it('should read config files from disk', (done) => {
        const config = new Config(goodDataDir);

        config.validate().then(() => {
            const expected = {
                username: 'foo',
                password: 'bar',
                something_else: 'baz',
                cf_datastore_location: '/tmp',
                owner_account: 'TheGuardian',
                client_secrets: 'shh.json',
                private_key: 'private.pem',
                passphrase: 'DontTellAnyone',
                media_atom_url_base: 'https://no.where',
                media_atom_shared_secret: 'CanYouKeepASecret',
                media_atom_poster_dir: '/tmp'
            };

            const actual = config.config;
            assert.deepEqual(actual, expected);
            done();
        });
    });

    it('should add extra properties when .withDateConfig is called', (done) => {
        const config = new Config(goodDataDir);

        const date = new Date("2016-01-01 00:00:00");

        config.validate().then(() => {
            const actual = config.withDateConfig(date);

            const expected = {
                username: 'foo',
                password: 'bar',
                something_else: 'baz',
                cf_datastore_location: '/tmp',
                owner_account: 'TheGuardian',
                client_secrets: 'shh.json',
                private_key: 'private.pem',
                passphrase: 'DontTellAnyone',
                media_atom_url_base: 'https://no.where',
                media_atom_shared_secret: 'CanYouKeepASecret',
                media_atom_poster_dir: '/tmp',
                year: 2016,
                month: 1,
                day: 1,
                hour: 0,
                min: 0,
                sec: 0
            };

            assert.deepEqual(actual, expected);
            done();
        });
    });

    it('should fail to validate when there are missing config keys', (done) => {
        const config = new Config(badDataDir);

        config.validate().catch(actual => {
            const expected = [
                'cf_datastore_location',
                'client_secrets',
                'private_key',
                'passphrase',
                'media_atom_shared_secret',
                'media_atom_poster_dir'
            ];

           assert.deepEqual(actual, expected);
           done();
        });
    });
});
