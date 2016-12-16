const assert = require('assert');
const path = require('path');
const sinon = require('sinon');
const Database = require('../../datastore/db');
const Config = require('../../datastore/config');
const StringSubstitution = require('../../datastore/string-substitution');

const dataDir = path.join(__dirname, '../data');

describe('DataStore String Substitution', () => {
    it('should substitute with values read from a config file', (done) => {
        const db = new Database('test');
        const conf = new Config(dataDir);

        const subs = new StringSubstitution(db, conf);

        const template = '{config:username} test';

        const expected = 'foo test';

        subs.substituteString(template).then(actual => {
            assert.equal(actual, expected);
            done();
        });
    });

    it('should substitute date parts', (done) => {
        const db = new Database('test');
        const conf = new Config(dataDir);

        const subs = new StringSubstitution(db, conf);

        const template = 'Wake up {config:username}! Its the year {year}';

        const expected = `Wake up foo! Its the year ${new Date().getFullYear()}`;

        subs.substituteString(template).then(actual => {
            assert.equal(actual, expected);
            done();
        }).catch(e => {
            console.log(e);
        });
    });

    it('should accept a list of strings to substitute', (done) => {
        const db = new Database('test');
        const conf = new Config(dataDir);

        const subs = new StringSubstitution(db, conf);

        const templates = [
            '{config:username} test',
            'Wake up {config:username}! Its the year {year}'
        ];

        subs.substituteStrings(templates).then(actual => {
            assert.ok(actual.length === 2);
            assert.ok(actual.includes('foo test'));
            assert.ok(actual.includes(`Wake up foo! Its the year ${new Date().getFullYear()}`));
            done();
        }).catch(e => {
            console.log(e);
        });
    });
});