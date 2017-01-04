#!/usr/bin/env node

const Config = require('../datastore/config');
const Database = require('../datastore/db');
const Logger = require('../logger');

const path = require('path');
const scriptName = path.basename(__filename);

if (process.argv.length !== 3) {
    Logger.error(`Usage: ./${scriptName} <ATOM_ID>`);
    process.exit(1);
}

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});
const ATOM_ID = process.argv[2];

config.validate().then(() => {
    const database = new Database({whoami: scriptName, datastoreLocation: config.datastoreLocation});
    database.setOne('meta', 'gnm_master_mediaatom_atomid', ATOM_ID).then(() => {
        process.exit(0);
    }).catch(() => {
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});
