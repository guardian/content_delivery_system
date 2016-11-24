#!/bin/bash -e
cd "${0%/*}"
data_store="/tmp/test.db"
if [ -f $data_store ]; then
    echo 'datastore!!'
    rm $data_store
fi
export "cf_datastore_location"=$data_store;
cd ..
./cds_create_datastore.pl
./cds_datastore.pl set meta youtube_id id
export "url_base"="";
export "shared_secret"="";
export "atom_id"="";
node ./scripts/active_asset.js
