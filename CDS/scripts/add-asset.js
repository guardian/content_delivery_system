#!/usr/bin/env node

//This method uploads an asset to an atom by posting a request to
//media atom maker.
//It expects the following arguments:
//<url_base> the base of media atom maker url
//<shared_secret> secret shared with media atom maker that allows posting to it

var asset = require('../js/add-asset-lib');

asset.postAsset()
.then(response => {
    console.log('+SUCCESS: added an asset ', response);
    if (process.env.debug) {
        console.log('response returned ', response);
    }

    process.exit();
}).catch(error => {
    console.log('-ERROR in adding an asset ', error);
    process.exit(1);
});
