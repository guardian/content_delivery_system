#!/bin/bash -e
cd "${0%/*}"
data_store="/tmp/test.db"
if [ -f $data_store ]; then
    rm $data_store
fi
cd ../..
export "cf_datastore_location"=$data_store;
./cds_create_datastore.pl
./cds_datastore.pl set meta key value
export "cnf_media_file"="";
export "client_secrets"="";
export "title"="";
export "description"="";
export "category_id"="";
export "access"="";
export "owner_account"="";
export "owner_channel"="";
export "passphrase"="";
export "private_key"="";
node ./scripts/youtube-upload.js
