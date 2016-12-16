const tmpl = require('lodash.template');

class StringSubstitution {
    constructor (database, config) {
        this.database = database;

        this.config = config;

        // lodash templates break with the `:` character in a match,
        // so replace `:` with this value
        this.namespaceChar = this.config.namespaceChar;
    }

    // accepts a string from a route file of the form
    // `{replace:me} and dance`
    substituteString (templateString) {
        return new Promise((resolve, reject) => {
            this._getDbValuesFromTemplateString(templateString).then(dbConfig => {
                const allConfig = Object.assign({}, this.config.withDateConfig(), dbConfig);

                const templateOptions = { interpolate: /\{(.+?)}/g };

                const safeTemplateString = templateString.replace(/:/g, this.namespaceChar);

                const templateFn = tmpl(safeTemplateString, templateOptions);

                resolve(templateFn(allConfig));
            }).catch(err => reject(err));
        });
    }

    substituteStrings (templateStrings) {
        return Promise.all(templateStrings.map(str => this.substituteString(str)));
    }

    _getDbValuesFromTemplateString (templateString) {
        const dbSubList = this._getUniqueDbSubstitutions(templateString);

        if (dbSubList.length === 0) {
            return new Promise(resolve => resolve({}));
        }

        const queries = dbSubList.reduce((list, item) => {
            // item looks like `{meta:foo}`
            const [type, key] = item.match(/(\w+)(\w+)/g);

            list.push(this.database.getOne(type, key));

            return list;
        }, []);

        return Promise.all(queries).then(data => {
            return data.reduce((all, item) => {
                all[`${item.type}${this.namespaceChar}${item.key}`] = item.value;
                return all;
            }, {});
        });
    }

    _getUniqueDbSubstitutions (templateString) {
        const re = new RegExp(`\{((${this.database.recordTypes.join('|')}):(.+?))}`, 'g');
        const matches = templateString.match(re);
        return [...new Set(matches)];
    }
}

module.exports = StringSubstitution;