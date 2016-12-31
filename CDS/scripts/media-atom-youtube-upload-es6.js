const Config = require('./js_utils/datastore/config');
const Database = require('./js_utils/datastore/db');
const CdsModel = require('./js_utils/media-atom/model/cds-model');
const YoutubeAuth = require('./js_utils/media-atom/youtube-auth');
const YoutubeVideoUpload = require('./js_utils/media-atom/youtube-upload');
const YoutubePosterUpload = require('./js_utils/media-atom/youtube-poster');
const Logger = require('./js_utils/logger');

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate(['cf_media_file']).then(() => {
    const database = new Database({whoami: 'media-atom-youtube-upload-es6', datastoreLocation: config.datastoreLocation});

    const cdsModel = new CdsModel({database: database});

    const ytAuth = new YoutubeAuth({config: config});

    ytAuth.getAuthedYoutubeClient(client => {
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