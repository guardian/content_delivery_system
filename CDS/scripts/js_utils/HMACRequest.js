var reqwest = require('reqwest');
var hmac = require('./hmac');

module.exports = {
  makeRequest: function(connection, date, uri, urlBase, method, data) {

    return hmac.makeHMACToken(connection, date, uri)
    .then(token => {

      const requestBody = {
        url: urlBase + uri,
        method: method,
        contentType: 'application/json',
        headers: {
          'X-Gu-Tools-HMAC-Date': date,
          'X-Gu-Tools-HMAC-Token': token,
          'X-Gu-Tools-Service-Name': 'content_delivery_system'
        }
      };

      if (data) {
        requestBody.data = JSON.stringify(data);
      }

      return reqwest(requestBody);
    });
  }
};
