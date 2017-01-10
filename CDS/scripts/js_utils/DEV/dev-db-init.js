#!/usr/bin/env node

const ArgumentParser = require('argparse').ArgumentParser;
const path = require('path');

const Config = require('../datastore/config');
const DatabaseInit = require('../datastore/db-init');
const Database = require('../datastore/db');
const Logger = require('../logger');

const parser = new ArgumentParser();

parser.addArgument('--atom-id', {dest: 'atomId'});
parser.addArgument('--youtube-id', {dest: 'youtubeId'});
parser.addArgument('--pluto-id', {dest: 'plutoId'});

const args = parser.parseArgs();

const scriptName = path.basename(__filename);

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate().then(() => {
    new DatabaseInit({datastoreLocation: config.datastoreLocation}).then(() => {
        const database = new Database({whoami: scriptName, datastoreLocation: config.datastoreLocation});

        const promises = [];

        if (args.atomId) {
            promises.push(database.setOne('meta', 'gnm_master_mediaatom_atomid', args.atomId));
        }

        if (args.youtubeId) {
            promises.push(database.setOne('meta', 'atom_youtubeId', args.youtubeId));
        }

        if (args.plutoId) {
            promises.push(database.setOne('meta', 'itemId', args.plutoId));
        }

        Promise.all(promises).then(() => {
            process.exit();
        }).catch(error => {
            Logger.error(error);
            process.exit(1);
        });
    }).catch(() => {
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});
