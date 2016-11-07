#!/usr/bin/env node

//This method fetches atom metadata from the media atom maker api
//It expects the following arguments:
//<url_base> the base of the media atom maker url
//<shared_secret> secret shared with the media atom maker that allows fetching data from the api
//<atom_id> the id of the atom data is being fetched from

var mediaAtomLib = require('../js/media-atom-lib');
var dataStore = require('../js/Datastore');

var connection = new dataStore.Connection("fetch-metadata.js");
dataStore.initialiseDb();

mediaAtomLib.fetch(connection)
.then(response => {
    console.log('+SUCCESS: Fetched metadata successfully from atom with id ', );
    if (process.env.debug) {
        console.log('response returned from youtube api ', response);
    }

    process.exit();

}).catch(err => {
    console.log('-ERROR in fetching metadata from media atom maker ', err);
    process.exit(1);
});

