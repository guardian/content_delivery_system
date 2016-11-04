var chai = require('chai');
var assert = chai.assert;
var  chaiAsPromised = require('chai-as-promised');
var sinon = require('sinon');

chai.use(chaiAsPromised);

var fs = require('fs');
var sinon = require('sinon');
var youtubeUpload = require('../../youtube/youtube-upload-lib');
var youtubeAuth = require('../../youtube/youtube-auth');
var googleapis = require('googleapis');
var dataStore = require('../../Datastore');

describe('YoutubeUpload', () => {
    var stringSubstituteStub;

    beforeEach(() => {
        stringSubstituteStub = sinon.stub(dataStore, 'substituteStrings', (connection, val) => {
            return new Promise((fulfill) => {
                fulfill(val);
            });
        });

    });

    afterEach(() => {
        stringSubstituteStub.restore();
    });

    after(() => {
        delete process.env.cf_datastore_location;
    });

    describe('#getYoutubeData', () => {
        var metadataStub, readStub;

        beforeEach(() => {
            process.env.cf_media_file = './media';
            process.env.owner_account = 'account';
            process.env.owner_channel = 'channel';
            metadataStub = sinon.stub(youtubeUpload, 'getMetadata').returns(new Promise((fulfill, reject) => {
                fulfill({});
            }));
            readStub = sinon.stub(fs, 'createReadStream');

        });

        afterEach(() => {
            delete process.env.media_path;
            delete process.env.owner_account;
            delete process.env.owner_channel;
            metadataStub.restore();
            readStub.restore();
        });

        it('should parse youtube data correctly when all variables exist', () => {

            return youtubeUpload.getYoutubeData(null)
            .then((data) => {
                assert.equal(data.part, 'snippet,status');
                assert.ok(data.resource);
                assert.ok(data.media);

                assert.equal(data.onBehalfOfContentOwner, 'account');
                assert.equal(data.onBehalfOfContentOwnerChannel, 'channel');
                assert.equal(data.uploadType, 'multipart');
                sinon.assert.calledOnce(stringSubstituteStub);
                return;
            });
        });

        it('should raise an exception if no media path provided', () => {

            delete process.env.cf_media_file;

            return assert.isRejected(youtubeUpload.getYoutubeData(), 'Cannot upload to youtube: missing media file path. Make sure that media has been specified in the route');

        });

        it('should raise an exception if channel is specified without an account owner', () => {
            delete process.env.owner_account;

            assert.isRejected(youtubeUpload.getYoutubeData(), 'Cannot upload to youtube: missing account owner');

        });

        it('should not include content owner and channel if owner and channel parameters are missing', () => {
            delete process.env.owner_account;
            delete process.env.owner_channel;

            return youtubeUpload.getYoutubeData(null)
            .then((data) => {

                assert.equal(data.onBehalfOfContentOwner, undefined);
                assert.equal(data.onBehalfOfContentOwnerChannel, undefined);
            });
        });

    });

    describe('#getMetadata', () => {

        const CATEGORY_ID = 2;

        beforeEach(() => {
            process.env.title = 'title';
            process.env.description = 'description';
            process.env.category_id = CATEGORY_ID;
            process.env.access = 'status';
        });

        afterEach(() => {
            delete process.env.title;
            delete process.env.description;
            delete process.env.category_id;
            delete process.env.access;
        });

        it('should parse metadata when all environment variables exist', () => {
            return youtubeUpload.getMetadata()
            .then((metadata) => {

                assert.ok(metadata.snippet);
                const snippet = metadata.snippet;

                assert.ok(metadata.status);
                const status = metadata.status.privacyStatus;

                assert.equal(snippet.title, 'title');
                assert.equal(snippet.description, 'description');
                assert.equal(snippet.categoryId, CATEGORY_ID);
                assert.equal(status, 'status');
                return;
            });
        });

        it('should throw if no title provided', () => {
            delete process.env.title;

            return assert.isRejected(youtubeUpload.getMetadata(), 'Cannot upload to youtube: missing a title');

        });

        it('should throw if no description provided', () => {
            delete process.env.description;

            return assert.isRejected(youtubeUpload.getMetadata(), 'Cannot upload to youtube: missing a description');

        });

        it('should throw if no category provided', () => {
            delete process.env.category_id;

            return assert.isRejected(youtubeUpload.getMetadata(), 'Cannot upload to youtube: missing a category id');
        });

        it('should use default status if no status provided', () => {
            delete process.env.access;
            return youtubeUpload.getMetadata()
            .then((metadata) => {
                const status = metadata.status.privacyStatus;
                return assert.equal(status, 'private');
            });
        });
    });
    describe('#uploadToYoutube', () => {

        var authStub, youtubeStub, dataStub, saveResultsStub;

        before(() => {
            authStub = sinon.stub(youtubeAuth, 'getAuthClient');
            authStub.returns(new Promise((fulfill) => {
                fulfill({});
            }));

            youtubeStub = sinon.stub(googleapis, 'youtube');
            youtubeStub.returns({
                videos: {
                    insert: function(data, cb) {
                        var result = {
                            id: 'id'
                        };
                        cb(null, result);
                    }
                }
            });

            dataStub = sinon.stub(youtubeUpload, 'getYoutubeData');
            dataStub.returns(new Promise((fulfill) => {
                fulfill({});
            }));

            saveResultsStub = sinon.stub(dataStore, 'set');
            saveResultsStub.returns(new Promise((fulfill) => {
                fulfill({});
            }));
        });

        after(() => {
            authStub.restore();
            youtubeStub.restore();
            dataStub.restore();
            saveResultsStub.restore();
        });


        it('should upload to youtube', () => {

            return youtubeUpload.uploadToYoutube()
            .then((result) => {
                sinon.assert.calledOnce(authStub);
                sinon.assert.calledOnce(youtubeStub);
                sinon.assert.calledOnce(dataStub);
                sinon.assert.calledOnce(saveResultsStub);
                assert.equal(result.id, 'id');
                return;
            });
        });
    });
});
