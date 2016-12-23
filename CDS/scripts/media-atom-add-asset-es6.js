const Config = require('./js_utils/datastore/config');
const Database = require('./js_utils/datastore/db');
const CdsModel = require('./js_utils/media-atom/model/cds-model');
const HmacRequest = require('./js_utils/media-atom/hmac');
const MediaAtom = require('./js_utils/media-atom/media-atom');
const Logger = require('./js_utils/logger');

const config = new Config();

config.validate().then(() => {
    const database = new Database('media-atom-add-asset-es6', config.datastoreLocation);
    const cdsModel = new CdsModel(database);
    const hmacRequest = new HmacRequest(config);

    const mediaAtom = new MediaAtom(cdsModel, config, hmacRequest);

    mediaAtom.addAsset().then(() => {
        process.exit();
    }).catch(e => {
        Logger.error(e);
        process.exit(1);
    });
}).catch(missingConfig => {
    Logger.error(`missing config values ${missingConfig.join(', ')}`);
    process.exit(1);
});