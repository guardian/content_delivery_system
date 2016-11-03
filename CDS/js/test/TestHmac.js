var chai = require('chai');
var assert = chai.assert;
var chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

var crypto = require('crypto');
var hmac = require('../hmac');
var datastore = require('../datastore');

describe('hmac', () => {

    describe('#makeHMACToken', () => {

        it('should raise an exeption if shared secret is missing', () => {

            return assert.isRejected(hmac.makeHMACToken(), 'Cannot add assets to media atom maker: missing shared secre');

        });

        it('should return a token ', () => {
            process.env.shared_secret = 'secret';

            substituteStub = sinon.stub(datastore, 'substituteString', (connection, value) => {
                return new Promise(fulfill => {
                    fulfill(value);
                });
            });


            var createHmac = sinon.stub(crypto, 'createHmac').returns({
                update: function() { return; },
                digest: function() { return; }
            });

            return hmac.makeHMACToken()
            .then(val => {
                sinon.assert.calledOnce(createHmac);
                sinon.assert.calledOnce(substituteStub);
                createHmac.restore();
                return;
            });
        });
    });
});

