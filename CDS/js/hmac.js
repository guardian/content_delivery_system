const crypto = require('crypto');

module.exports = {
    makeHMACToken: function(date, uri) {

        return new Promise((fulfill, reject) => {

            if (!process.env.shared_secret) {
                reject(new Error('Cannot add assets to media atom maker: missing shared secret'));
            }

            const sharedSecret = process.env.shared_secret;

            const hmac = crypto.createHmac('sha256', sharedSecret);
            const content = date + '\n' + uri;

            hmac.update(content, 'utf-8');

            fulfill("HMAC " + hmac.digest('base64'));
        });

    }
};
