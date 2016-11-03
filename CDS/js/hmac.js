var crypto = require('crypto');
process.env.cf_datastore_location = "";
var datastore = require('./Datastore');

module.exports = {
    makeHMACToken: function(connection, date, uri) {

        if (!process.env.shared_secret) {
            return new Promise((fulfill, reject) => {
                reject(new Error('Cannot add assets to media atom maker: missing shared secret'));
            });
        }

        return datastore.substituteString(connection, process.env.shared_secret)
        .then(sharedSecret => {

            const hmac = crypto.createHmac('sha256', sharedSecret);
            const content = date + '\n' + uri;

            hmac.update(content, 'utf-8');

            return "HMAC " + hmac.digest('base64');
        });
    }
};
