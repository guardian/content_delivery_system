#!/usr/bin/env node

const Config = require('../datastore/config');
const DatabaseInit = require('../datastore/db-init');
const Logger = require('../logger');

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate().then(() => {
    new DatabaseInit({datastoreLocation: config.datastoreLocation}).then(() => {
        process.exit();
    }).catch(() => {
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});
