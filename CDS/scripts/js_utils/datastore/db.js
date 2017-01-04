const sqlite3 = require('sqlite3');

const Logger = require('../logger');

class Database {
    constructor ({whoami, datastoreLocation = ':memory:'}) {
        this.db = new sqlite3.Database(datastoreLocation);

        this.whoami = whoami;

        this.recordTypes = [ 'meta', 'media', 'tracks' ];
    }

    close () {
        this.db.close();
    }

    getOne (type, key) {
        return new Promise((resolve, reject) => {
            if (! this.recordTypes.includes(type)) {
                reject(`type must be ${this.recordTypes.join(', ')}`);
            }

            this._getOrCreateSource(type).then(() => {
                this.db.serialize(() => {
                    const sql = `
                        SELECT  value 
                        FROM    ${type} 
                        WHERE   key = ?;`;

                    this.db.prepare(sql).get(key, (err, row) => {
                        if (err) {
                            reject(err);
                        }

                        const value = row && row.value;
                        const response = { value: value, type: type, key: key };

                        resolve(response);
                    });

                });
            });
        });
    }

    setOne (type, key, value) {
        return this.setMany(type, {[key]: value})
    }

    setMany (type, meta) {
        return new Promise((resolve, reject) => {
            if (! this.recordTypes.includes(type)) {
                reject(`type must be ${this.recordTypes.join(', ')}`);
            }

            this._getOrCreateSource(type).then(sourceId => {
                const sql = `
                    INSERT INTO ${type} 
                    (source_id, key, value) 
                    VALUES (?, ?, ?);`;

                const promises = Object.keys(meta).map(key => new Promise((resolve, reject) => {
                    const values = [sourceId, key, meta[key]];

                    // callback is not an arrow function as need `this` to be old school to access `lastID`
                    // https://github.com/mapbox/node-sqlite3/wiki/API#databaserunsql-param--callback
                    this.db.prepare(sql).run(values, function (err) {
                        if (! err) {
                            Logger.info(`inserted new ${type}. key: ${key}, value: ${meta[key]}. ID ${this.lastID}`);
                            resolve(this.lastID);
                        } else {
                            reject(err);
                        }
                    });
                }));

                Promise.all(promises)
                    .then(values => resolve(values))
                    .catch(err => reject(err));
            });
        });
    }

    _getOrCreateSource (type) {
        return new Promise((resolve, reject) => {
            this._getSource(type)
                .then(id => resolve(id))
                .catch(() => {
                    this._createSource(type)
                        .then(newId => resolve(newId))
                        .catch(err => reject(err));
                });
        });
    }

    _getSource (type) {
        const sql = `
            SELECT  id 
            FROM    sources 
            WHERE   type = ? 
            AND     provider_method = ?;`;

        const values = [type, this.whoami];

        return new Promise((resolve, reject) => {
            this.db.prepare(sql).get(values, (err, row) => row ? resolve(row.id) : reject(err));
        });
    }

    _createSource (type) {
        const sql = `
            INSERT INTO sources (
                type, 
                provider_method, 
                ctime
            ) 
            VALUES (?, ?, ?);`;

        const values = [type, this.whoami, Math.floor(Date.now())];

        return new Promise((resolve, reject) => {
            // callback is not an arrow function as need `this` to be old school to access `lastID`
            // https://github.com/mapbox/node-sqlite3/wiki/API#databaserunsql-param--callback
            this.db.prepare(sql).run(values, function(err) {
                if (! err) {
                    Logger.info(`inserted new source with ID ${this.lastID}`);
                    resolve(this.lastID);
                } else {
                    reject(err);
                }
            });
        });
    }
}

module.exports = Database;