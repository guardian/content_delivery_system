#!/bin/bash -e
cd "${0%/*}"
data_store="/tmp/test.db"
if [ -f $data_store ]; then
    rm $data_store
fi
export "cf_datastore_location"=$data_store;
cd ..
./cds_create_datastore.pl
#Change the values here to what you want to get set in the datastore
./cds_datastore.pl set meta youtube_url url
./cds_datastore.pl set meta atom_id id
export "url_base"="";
export "shared_secret"="";
node ./scripts/add-asset.js
