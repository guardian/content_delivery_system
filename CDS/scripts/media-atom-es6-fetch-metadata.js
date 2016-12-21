const Config = require('./js_utils/datastore/config');
const Database = require('./js_utils/datastore/db');
const CdsModel = require('./js_utils/media-atom/model/cds-model');
const HmacRequest = require('./js_utils/media-atom/hmac');
const MediaAtom = require('./js_utils/media-atom/media-atom');

try {
    const config = new Config();
    const database = new Database('es6-fetch-metadata', config.cf_datastore_location);
    const cdsModel = new CdsModel(database);
    const hmacRequest = new HmacRequest(config);

    const mediaAtom = new MediaAtom(cdsModel, config, hmacRequest);

    mediaAtom.fetchAndSaveMetadata().then(() => {
        process.exit();
    }).catch(e => {
        process.exit(1);
    });

} catch (e) {
    // the constructors are not Promises and throw exceptions if a config value is missing
    console.log(e);
    process.exit(1);
}
