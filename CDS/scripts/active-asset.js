#!/usr/bin/env node

//This method makes an asset active once youtube video encoding is finished
//by polling the youtube api.
//It expects the following arguments:
//<url_base> the base of media atom maker url
//<shared_secret> secret shared with media atom maker that allows posting to it
//<atom_id> id of the atom the asset is being added to

var mediaAtomLib = require('../js/media-atom-lib');
var dataStore = require('../js/Datastore');

var connection = new dataStore.Connection("add-asset.js");

mediaAtomLib.makeAssetActive(connection)
.then(response => {
  console.log('+SUCCESS: made an asset active ', response);
    process.exit();
}).catch(error => {
    console.log('-ERROR in making an asset active ', error);
    process.exit(1);
});
