const path = require('path');
const fs = require('fs');
const PropertiesReader = require('properties-reader');

class Config {
    constructor (configDirectory = '/etc/cds_backend/conf.d', namespaceChar = '_') {
        this.configDirectory = configDirectory;
        this.namespaceChar = namespaceChar;

        const baseConfig = this._getEnvironmentConfig();

        try {
            this.config = fs.readdirSync(this.configDirectory)
                .filter(f => f.endsWith('.conf'))
                .reduce((properties, fileName) => {
                    const filePath = path.join(this.configDirectory, fileName);
                    const props = PropertiesReader(filePath).getAllProperties();
                    return Object.assign({}, properties, this._namespaceConfig(props, 'config'));
                }, baseConfig);
        }
        catch (e) {
            // cannot read files in `this.configDirectory`
            this.config = baseConfig;
        }
    }

    _getEnvironmentConfig () {
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
        }

        return conf;
    }

    _namespaceConfig (config, namespace) {
        return Object.keys(config).reduce((result, key) => {
            result[`${namespace}${this.namespaceChar}${key}`] = config[key];
            return result;
        }, {});
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
}

module.exports = Config;