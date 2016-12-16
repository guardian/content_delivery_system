const sqlite3 = require('sqlite3');

class Database {
    constructor (whoami, datastoreLocation = ':memory:') {
        const self = this;

        self.db = new sqlite3.Database(datastoreLocation);

        self.whoami = whoami;

        self.recordTypes = [ 'meta', 'media', 'tracks' ];
    }

    close () {
        this.db.close();
    }

    getOne (type, key) {
        const self = this;

        if (! self.recordTypes.includes(type)) {
            throw `type must be ${self.recordTypes.join(', ')}`;
        }

        return new Promise((resolve, reject) => {
            self._getOrCreateSource(type).then(() => {
                self.db.serialize(() => {
                    const sql = `
                        SELECT  value 
                        FROM    ${type} 
                        WHERE   key = ?;`;

                    self.db.prepare(sql).get(key, (err, row) => {
                        if (err) {
                            reject(err);
                        }

                        const value = row && row.value || 'value not found';
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
        const self = this;

        if (! self.recordTypes.includes(type)) {
            throw `type must be ${self.recordTypes.join(', ')}`;
        }

        return new Promise((resolve, reject) => {
            self._getOrCreateSource(type).then(sourceId => {
                const sql = `
                    INSERT INTO ${type} 
                    (source_id, key, value) 
                    VALUES (?, ?, ?);`;

                const promises = Object.keys(meta).map(key => new Promise((resolve, reject) => {
                    const values = [sourceId, key, meta[key]];
                    self.db.prepare(sql).run(values, (err) => ! err ? resolve() : reject(err));
                }));

                Promise.all(promises)
                    .then(values => resolve())
                    .catch(err => reject(err));
            });
        });
    }

    _getOrCreateSource (type) {
        const self = this;

        return new Promise((resolve, reject) => {
            self._getSource(type)
                .then(id => resolve(id))
                .catch(() => {
                    self._createSource(type)
                        .then(newId => resolve(newId))
                        .catch(err => reject(err));
                });
        });
    }

    _getSource (type) {
        const self = this;

        const sql = `
            SELECT  id 
            FROM    sources 
            WHERE   type = ? 
            AND     provider_method = ?;`;

        const values = [type, self.whoami];

        return new Promise((resolve, reject) => {
            self.db.prepare(sql).get(values, (err, row) => row ? resolve(row.id) : reject(err));
        });
    }

    _createSource (type) {
        const self = this;

        const sql = `
            INSERT INTO sources (
                type, 
                provider_method, 
                ctime
            ) 
            VALUES (?, ?, ?);`;

        const values = [type, self.whoami, Math.floor(Date.now())];

        return new Promise((resolve, reject) => {
            self.db.prepare(sql).run(values, function(err) {
                return ! err ? resolve(this.lastID) : reject(err);
            });
        });
    }
}

module.exports = Database;