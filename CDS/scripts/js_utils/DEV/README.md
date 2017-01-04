# `dev-db-init.js`

Use this script in DEV to initialise a SQLLite database with some values. This is useful for when you want to execute a CDS method locally.

## Setup

### Config
Create a config file in `/etc/cds_backend/conf.d/cds-DEV.conf`. This file should have the keys:

```properties
# youtube properties (ask your friendly colleagues)
owner_account =
client_secrets =
private_key =
passphrase =

# media atom properties
media_atom_url_base = https://media-atom-maker.domain.co.uk
media_atom_shared_secret = shh
media_atom_poster_dir = /tmp

cf_datastore_location = /path/to/save/db/to/cds.db
cf_media_file = /path/to/a/video/to/upload.mp4
```

## Example usage
If you want to fetch a Media Atom's metadata:

```bash
./dev-db-init.js --atom-id foo
../media-atom/routes/fetch-metadata.js
```

This'll make a `GET` request to the Media Atom API for the Atom `foo`. Obviously, the Atom `foo` should exist on the `media_atom_url_base` endpoint.