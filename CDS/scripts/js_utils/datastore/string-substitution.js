const tmpl = require('lodash.template');

class StringSubstitution {
    constructor (database, config) {
        const self = this;

        self.database = database;

        self.config = config;

        // lodash templates break with the `:` character in a match,
        // so replace `:` with this value
        self.namespaceChar = self.config.namespaceChar;
    }

    // accepts a string from a route file of the form
    // `{replace:me} and dance`
    substituteString (templateString) {
        const self = this;

        return new Promise((resolve, reject) => {
            self._getDbValuesFromTemplateString(templateString).then(dbConfig => {
                const allConfig = Object.assign({}, self.config.withDateConfig(), dbConfig);

                const templateOptions = { interpolate: /\{(.+?)}/g };

                const safeTemplateString = templateString.replace(/:/g, self.namespaceChar);

                const templateFn = tmpl(safeTemplateString, templateOptions);

                resolve(templateFn(allConfig));
            }).catch(err => reject(err));
        });
    }

    substituteStrings (templateStrings) {
        const self = this;
        return Promise.all(templateStrings.map(str => self.substituteString(str)));
    }

    _getDbValuesFromTemplateString (templateString) {
        const self = this;

        const dbSubList = self._getUniqueDbSubstitutions(templateString);

        if (dbSubList.length === 0) {
            return new Promise(resolve => resolve({}));
        }

        const queries = dbSubList.reduce((list, item) => {
            // item looks like `{meta:foo}`
            const [type, key] = item.match(/(\w+)(\w+)/g);

            list.push(self.database.getOne(type, key));

            return list;
        }, []);

        return Promise.all(queries).then(data => {
            return data.reduce((all, item) => {
                all[`${item.type}${self.namespaceChar}${item.key}`] = item.value;
                return all;
            }, {});
        });
    }

    _getUniqueDbSubstitutions (templateString) {
        const self = this;

        const re = new RegExp(`\{((${self.database.recordTypes.join('|')}):(.+?))}`, 'g');
        const matches = templateString.match(re);
        return [...new Set(matches)];
    }
}

module.exports = StringSubstitution;