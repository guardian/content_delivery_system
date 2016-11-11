#!/usr/bin/env node

//This method uploads an asset to an atom by posting a request to
//media atom maker.
//It expects the following arguments:
//<url_base> the base of media atom maker url
//<shared_secret> secret shared with media atom maker that allows posting to it
//<atom_id> id of the atom the asset is being added to

var mediaAtomLib = require('./js_utils/media-atom-lib');
var dataStore = require('./js_utils/Datastore');

var connection = new dataStore.Connection("add-asset.js");

mediaAtomLib.postAsset(connection)
.then(response => {
    console.log('+SUCCESS: added an asset to ', response._url.path);
    if (process.env.debug) {
        console.log('response returned ', response);
    }

    process.exit();
}).catch(error => {
    console.log('-ERROR in adding an asset ', error);
    process.exit(1);
});
