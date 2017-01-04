const assert = require('assert');
const path = require('path');
const Config = require('../../datastore/config');

const dataDir = path.join(__dirname, '../data');

describe('DataStore Config', () => {
    it('should read config files from disk', (done) => {
        const c = new Config(dataDir);

        const expected = {
            username: 'foo',
            password: 'bar',
            something_else: 'baz'
        };

        const actual = c.config;

        assert.deepEqual(actual, expected);
        done();
    });

    it('should add extra properties when .withDateConfig is called', (done) => {
        const c = new Config(dataDir);

        const date = new Date("2016-01-01 00:00:00");

        const actual = c.withDateConfig(date);

        const expected = {
            username: 'foo',
            password: 'bar',
            something_else: 'baz',
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
