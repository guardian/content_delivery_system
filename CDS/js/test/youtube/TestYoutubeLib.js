var assert = require('assert');
var fs = require('fs');
var sinon = require('sinon');
var youtubeUpload = require('../../youtube/youtube-upload-lib');
var youtubeAuth = require('../../youtube/youtube-auth');
var googleapis = require('googleapis');

process.env.cf_datastore_location = 'datastore';

describe('YoutubeUpload', () => {

    describe('#getYoutubeData', () => {

        beforeEach(() => {
            process.env.cnf_media_file = './media';
            process.env.owner_account = 'account';
            process.env.owner_channel = 'channel';
        });

        afterEach(() => {
            delete process.env.media_path;
            delete process.env.owner_account;
            delete process.env.owner_channel;
        });

        it('should parse youtube data correctly when all variables exist', (done) => {

            var fsStub = sinon.stub(fs, 'readFileSync');

            const data = youtubeUpload.getYoutubeData();
            assert.equal(data.part, 'snippet,status');
            assert.ok(data.resource);
            assert.ok(data.media);

            assert.equal(data.onBehalfOfContentOwner, 'account');
            assert.equal(data.onBehalfOfContentOwnerChannel, 'channel');
            assert.equal(data.uploadType, 'multipart');

            done();
        });

        it('should raise an exception if no media path provided', (done) => {
            delete process.env.cnf_media_file;

            assert.throws(youtubeUpload.getYoutubeData, Error, 'Cannot upload to youtube: missing a file path');

            done();

        });

        it('should raise an exception if channel is specified without an account owner', (done) => {
            delete process.env.owner_account;

            assert.throws(youtubeUpload.getYoutubeData, Error, 'Cannot upload to youtube: missing account owner');

            done();

        });

        it('should include paramters if account owner are both missing', (done) => {
            delete process.env.owner_account;
            delete process.env.owner_channel;

            const data = youtubeUpload.getYoutubeData();

            assert.equal(data.onBehalfOfContentOwner, undefined);
            assert.equal(data.onBehalfOfContentOwnerChannel, undefined);

            done();

        });

    });

    describe('#getMetadata', () => {

        beforeEach(() => {
            process.env.title = 'title';
            process.env.description = 'description';
            process.env.category_id = 2;
            process.env.access = 'status';
        });

        afterEach(() => {
            delete process.env.title;
            delete process.env.description;
            delete process.env.category_id;
            delete process.env.access;
        });

        it('should parse metadata when all environment variables exist', (done) => {
            const metadata = youtubeUpload.getMetadata();

            assert.ok(metadata.snippet);
            const snippet = metadata.snippet;

            assert.ok(metadata.status);
            const status = metadata.status.privacyStatus;

            assert.equal(snippet.title, 'title');
            assert.equal(snippet.description, 'description');
            assert.equal(snippet.categoryId, 2);
            assert.equal(status, 'status');

            done();
        });

        it('should throw if no title provided', (done) => {
            delete process.env.title;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a title');

            done();
        });

        it('should throw if no description provided', (done) => {
            delete process.env.description;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a description');

            done();
        });

        it('should throw if no category provided', (done) => {
            delete process.env.category_id;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a category id');

            done();
        });

        it('should use default status if no status provided', (done) => {
            delete process.env.access;
            const metadata = youtubeUpload.getMetadata();
            const status = metadata.status.privacyStatus;

            assert.equal(status, 'private');

            done();
        });
    });
    describe('#uploadToYoutube', () => {

        it('should upload to youtube', () => {

            var authStub = sinon.stub(youtubeAuth, 'getAuthClient');
            authStub.returns(new Promise((fulfill) => {
                fulfill({});
            }));

            var youtubeStub = sinon.stub(googleapis, 'youtube');
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

            var dataStub = sinon.stub(youtubeUpload, 'getYoutubeData').returns({});

            var saveResultsStub = sinon.stub(youtubeUpload, 'saveResultToDataStore');

            saveResultsStub.returns(new Promise((fulfill) =>{
                fulfill();
            }));

            return youtubeUpload.uploadToYoutube()
            .then((result) => {
                sinon.assert.calledOnce(authStub);
                sinon.assert.calledOnce(youtubeStub);
                sinon.assert.calledOnce(dataStub);
                sinon.assert.calledOnce(saveResultsStub);
                assert.equal(result.id, 'id');
            });
        });
    });
});
