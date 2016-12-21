const sqlite3 = require('sqlite3');

const Logger = require('../logger');

class DatabaseInit {
    constructor (datastoreLocation = ':memory:') {
        this.db = new sqlite3.Database(datastoreLocation);

        Logger.info(`initialising database to ${datastoreLocation}`);

        const createSql = [
            `CREATE TABLE system (
                schema_version,
                cds_version
            );`,
            `CREATE TABLE sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type,
                provider_method,
                ctime,
                filename,
                filepath
            );`,
            `CREATE TABLE meta (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id,
                key,
                value
            );`,
            `CREATE TABLE tracks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id,
                track_index,
                key,
                value
            );`,
            `CREATE TABLE media (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id,
                key,
                value
            );`
        ];

        const insertSql = `INSERT INTO system (schema_version, cds_version) VALUES (1.0, 3.0);`;

        return new Promise((resolve, reject) => {
            this.db.serialize(() => {
                this.db.parallelize(() => createSql.forEach(sql => this.db.run(sql)));
                Logger.info('tables created');
                this.db.run(insertSql, (err) => {
                    if (err) {
                        reject(err);
                    } else {
                        Logger.info('system table updated');
                        resolve(this.db);
                    }
                });
            });
        });
    }
}

module.exports = DatabaseInit;