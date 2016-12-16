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
        const date = new Date("2016-01-01 00:00:00");

        const c = new Config(dataDir).withDateConfig(date);

        const actual = c.config;

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

    it('should add extra environment properties when .withExtraEnvironmentConfig is called', (done) => {
       process.env.foo = 'foo';
       process.env.bar = 'bar';

       const c = new Config(dataDir).withExtraEnvironmentConfig(['foo', 'bar']);

       assert.equal(c.config.foo, 'foo');
       assert.equal(c.config.bar, 'bar');

       done();
    });

    it('should handle method chaining', (done) => {
        process.env.foo = 'foo';
        process.env.bar = 'bar';

        const date = new Date("2016-01-01 00:00:00");

        const c = new Config(dataDir)
            .withExtraEnvironmentConfig(['foo', 'bar'])
            .withDateConfig(date);

        const expected = {
            username: 'foo',
            password: 'bar',
            something_else: 'baz',
            year: 2016,
            month: 1,
            day: 1,
            hour: 0,
            min: 0,
            sec: 0,
            foo: 'foo',
            bar: 'bar'
        };

        assert.deepEqual(c.config, expected);

        done();
    });
});
