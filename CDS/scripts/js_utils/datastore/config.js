const path = require('path');
const fs = require('fs');
const PropertiesReader = require('properties-reader');

const Logger = require('../logger');

class Config {
    constructor (configDirectory = '/etc/cds_backend/conf.d') {
        this.configDirectory = configDirectory;

        const baseConfig = this._getBaseConfig();

        this.config = fs.readdirSync(this.configDirectory)
            .filter(f => f.endsWith('.conf'))
            .reduce((properties, fileName) => {
                const filePath = path.join(this.configDirectory, fileName);
                Logger.info(`reading config from ${filePath}`);
                const props = PropertiesReader(filePath).getAllProperties();
                return Object.assign({}, properties, props);
            }, baseConfig);
    }

    _getBaseConfig () {
        const conf = {};

        if (process && process.env) {
            if (process.env.cf_route_name) {
                conf.route_name = process.env.cf_route_name;
            }

            if (process.env.HOSTNAME) {
                conf.hostname = process.env.HOSTNAME;
            }

            if (process.env.OSTYPE) {
                conf.ostype = process.env.OSTYPE;
            }

            if (process.env.cf_media_file) {
                conf.cf_media_file = process.env.cf_media_file;
            }

            if (process.env.cf_datastore_location) {
                conf.cf_datastore_location = process.env.cf_datastore_location;
            }
        }

        return conf;
    }

    withDateConfig (date = new Date()) {
        return Object.assign({}, this.config, {
            'year': date.getFullYear(),
            'month': date.getMonth() + 1,
            'day': date.getDate(),
            'hour': date.getHours(),
            'min': date.getMinutes(),
            'sec': date.getSeconds()
        });
    }

    validate (extraRequirements = []) {
        const requiredConfig = [
            // sqlite database location
            'cf_datastore_location',

            // Youtube config values
            'owner_account',
            'client_secrets',
            'private_key',
            'passphrase',

            // Media Atom config values
            'media_atom_url_base',
            'media_atom_shared_secret',
            'media_atom_poster_dir'
        ].concat(extraRequirements);

        return new Promise((resolve, reject) => {
            const missingItems = requiredConfig.reduce((missing, item) => {
                if (! Object.keys(this.config).includes(item)) {
                    missing.push(item);
                }
                return missing;
            }, []);

            if (missingItems.length === 0) {
                resolve(this);
            } else {
                reject(missingItems);
            }
        });
    }

    get datastoreLocation () {
        return this.config.cf_datastore_location;
    }

    get ownerAccount () {
        return this.config.owner_account;
    }

    get clientSecrets () {
        return this.config.client_secrets;
    }

    get privateKey () {
        return this.config.private_key;
    }

    get passphrase () {
        return this.config.passphrase;
    }

    get atomUrl () {
        return this.config.media_atom_url_base;
    }

    get atomSecret () {
        return this.config.media_atom_shared_secret;
    }

    get posterImageDownloadDir () {
        return this.config.media_atom_poster_dir;
    }

    get cfMediaFile () {
        return this.config.cf_media_file;
    }
}

module.exports = Config;
