#!/bin/bash -e
cd "${0%/*}"
data_store="/tmp/test.db"
if [ -f $data_store ]; then
    rm $data_store
fi
export "cf_datastore_location"=$data_store;
cd ../..
./cds_create_datastore.pl
export "url_base"="";
export "shared_secret"="";
export "atom_id"="";
node ./scripts/media-atom-fetch-metadata.js
