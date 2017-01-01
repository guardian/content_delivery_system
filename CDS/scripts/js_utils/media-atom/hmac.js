const crypto = require('crypto');
const reqwest = require('reqwest');
const url = require('url');

class HMACRequest {
    constructor ({config}) {
        this.config = config;
    }

    _getToken (remoteUrl, date) {
        const urlPath = url.parse(remoteUrl).pathname;
        const content = [date, urlPath].join('\n');

        const hmac = crypto.createHmac('sha256', this.config.atomSecret);
        hmac.update(content, 'utf-8');

        return `HMAC ${hmac.digest('base64')}`;
    }

    _request (remoteUrl, method, data = {}) {
        const date = new Date().toUTCString();
        const token = this._getToken(remoteUrl, date);

        const requestBody = {
            url: remoteUrl,
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

    get (remoteUrl) {
        return this._request(remoteUrl, 'GET');
    }

    post (remoteUrl, data) {
        return this._request(remoteUrl, 'POST', data);
    }

    put (remoteUrl, data) {
        return this._request(remoteUrl, 'PUT', data);
    }
}

module.exports = HMACRequest;