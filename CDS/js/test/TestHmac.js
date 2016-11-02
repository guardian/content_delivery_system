var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

var hmac = require('../hmac');
var crypto = require('crypto');

describe('#addAsset', () => {

    describe('#makeHMACToken', () => {

        it('should raise an exeption if shared secret is missing', () => {

            delete process.env.shared_secret;
            return assert.isRejected(hmac.makeHMACToken(), 'Cannot add assets to media atom maker: missing shared secre');

        });

        it('should return a token ', () => {
            process.env.shared_secret = 'secret';

            var createHmac = sinon.stub(crypto, 'createHmac').returns({
                update: function() { return; },
                digest: function() { return; }
            });

            return hmac.makeHMACToken("date")
            .then((val) => {
                sinon.assert.calledOnce(createHmac);
                createHmac.restore();
                return;
            });
        });
    });
});

