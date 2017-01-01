#!/usr/bin/env node

const Config = require('../../datastore/config');
const Database = require('../../datastore/db');
const CdsModel = require('../model/cds-model');
const YoutubeAuth = require('../youtube-auth');
const YoutubeVideoUpload = require('../youtube-upload');
const YoutubePosterUpload = require('../youtube-poster');
const Logger = require('../../logger');

const path = require('path');
const scriptName = path.basename(__filename, '.js');

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate(['cf_media_file']).then(() => {
    const database = new Database({whoami: scriptName, datastoreLocation: config.datastoreLocation});

    const cdsModel = new CdsModel({database: database});

    const ytAuth = new YoutubeAuth({config: config});

    ytAuth.getAuthedYoutubeClient().then(client => {
        const videoUpload = new YoutubeVideoUpload({cdsModel: cdsModel, config: config, youtubeAuthedClient: client});

        videoUpload.upload().then(() => {
            const posterUpload = new YoutubePosterUpload({cdsModel: cdsModel, config: config, youtubeAuthedClient: client});

            posterUpload.upload().then(() => {
                process.exit();
            }).catch(e => {
                Logger.error(e);
                process.exit(1);
            });
        }).catch(e => {
            Logger.error(e);
            process.exit(1);
        });
    }).catch(e => {
        Logger.error(e);
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});