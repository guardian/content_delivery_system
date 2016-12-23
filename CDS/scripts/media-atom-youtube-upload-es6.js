const Config = require('./js_utils/datastore/config');
const Database = require('./js_utils/datastore/db');
const CdsModel = require('./js_utils/media-atom/model/cds-model');
const YoutubeAuth = require('./js_utils/media-atom/youtube-auth');
const YoutubeVideoUpload = require('./js_utils/media-atom/youtube-upload');
const YoutubePosterUpload = require('./js_utils/media-atom/youtube-poster');
const Logger = require('./js_utils/logger');

const config = new Config();

config.validate(['cf_media_file']).then(() => {
    const database = new Database('media-atom-youtube-upload-es6', config.datastoreLocation);
    const cdsModel = new CdsModel(database);

    const ytAuth = new YoutubeAuth(config);

    ytAuth.getAuthedYoutubeClient(client => {
        const videoUpload = new YoutubeVideoUpload(cdsModel, config, client);

        videoUpload.upload().then(() => {
            const posterUpload = new YoutubePosterUpload(cdsModel, config, client);

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