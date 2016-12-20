const crypto = require('crypto');
const reqwest = require('reqwest');

class HMACRequest {
    constructor (configObj) {
        const requiredConfig = ['shared_secret'];

        requiredConfig.forEach(c => {
            if (! Object.keys(configObj.config).includes(c)) {
                throw `Invalid Config. Missing ${c}`;
            }
        });

        this.configObj = configObj;

        this.sharedSecret = this.configObj.config.shared_secret;
    }

    _getToken (url, date) {
        const hmac = crypto.createHmac('sha256', this.sharedSecret);
        const content = [date, url].join('\n');

        hmac.update(content, 'utf-8');

        return `HMAC ${hmac.digest('base64')}`;
    }

    _request (url, method, data = {}) {
        const date = new Date().toUTCString();
        const token = this._getToken(url, date);

        const requestBody = {
            url: url,
            method: method,
            contentType: 'application/json',
            headers: {
                'X-Gu-Tools-HMAC-Date': date,
                'X-Gu-Tools-HMAC-Token': token,
                'X-Gu-Tools-Service-Name': 'content_delivery_system'
            }
        };

        if (Object.keys(data).length > 0) {
            requestBody.data = JSON.stringify(data);
        }

        return reqwest(requestBody);
    }

    get (url) {
        return this._request(url, 'GET');
    }

    post (url, data) {
        return this._request(url, 'POST', data);
    }

    put (url, data) {
        return this._request(url, 'PUT', data);
    }
}

module.exports = HMACRequest;