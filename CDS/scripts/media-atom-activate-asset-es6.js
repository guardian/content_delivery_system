const Config = require('./js_utils/datastore/config');
const Database = require('./js_utils/datastore/db');
const CdsModel = require('./js_utils/media-atom/model/cds-model');
const HmacRequest = require('./js_utils/media-atom/hmac');
const MediaAtom = require('./js_utils/media-atom/media-atom');
const Logger = require('./js_utils/logger');

const config = new Config({configDirectory: '/etc/cds_backend/conf.d'});

config.validate().then(() => {
    const database = new Database({whoami: 'media-atom-activate-asset-es6', datastoreLocation: config.datastoreLocation});
    const cdsModel = new CdsModel({database: database});
    const hmacRequest = new HmacRequest({config: config});

    const mediaAtom = new MediaAtom({cdsModel: cdsModel, config: config, hmacRequest: hmacRequest});

    mediaAtom.activateAsset().then(() => {
        process.exit();
    }).catch(e => {
        Logger.error(e);
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});
