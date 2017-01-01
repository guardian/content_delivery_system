#!/usr/bin/env node

const Config = require('../../datastore/config');
const Database = require('../../datastore/db');
const CdsModel = require('../model/cds-model');
const HmacRequest = require('../hmac');
const MediaAtom = require('../media-atom');
const Logger = require('../../logger');

const path = require('path');
const scriptName = path.basename(__filename, '.js');

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate().then(() => {
    const database = new Database({whoami: scriptName, datastoreLocation: config.datastoreLocation});
    const cdsModel = new CdsModel({database: database});
    const hmacRequest = new HmacRequest({config: config});

    const mediaAtom = new MediaAtom({cdsModel: cdsModel, config: config, hmacRequest: hmacRequest});

    mediaAtom.fetchAndSaveMetadata().then(() => {
        process.exit();
    }).catch(e => {
        Logger.error(e);
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});
