const assert = require('assert');
const fs = require('fs');

var youtubeUpload = require('../../youtube/youtube-upload-lib');

describe('YoutubeUpload', function() {

    describe('#getYoutubeData', function() {

        beforeEach(function () {
            process.env.media_path = './media';
            process.env.owner_account = 'account';
            process.env.channel = 'channel';
        });

        it('should parse youtube data correctly when all variables exist', function(done) {

            const data = youtubeUpload.getYoutubeData();
            assert.equal(data.part, 'snippet,status');
            assert.ok(data.resource);

            assert.ok(data.parameters);
            assert.equal(data.parameters.onBehalfOfContentOwner, 'account');
            assert.equal(data.parameters.onBehalfOfContentOwnerChannel, 'channel');
            assert.ok(data.parameters);
            assert.equal(data.parameters.uploadType, 'multipart');

            done();
        });

        it('should raise an exception if no media path provided', function(done) {
            delete process.env.media_path;

            assert.throws(youtubeUpload.getYoutubeData(), Error, 'Cannot upload to youtube: missing a file path');

            done();

        });

        it('should raise an exception if channel is specified without an account owner', function(done) {
            delete process.env.owner_account;

            assert.throws(youtubeUpload.getYoutubeData, Error, 'Cannot upload to youtube: missing account owner');

            done();

        });

        it('should include paramters if account owner are both missing', function(done) {
            delete process.env.owner_account;
            delete process.env.channel;

            const data = youtubeUpload.getYoutubeData();

            assert.ok(data.parameters);
            assert.equal(data.parameters.onBehalfOfContentOwner, undefined);
            assert.equal(data.parameters.onBehalfOfContentOwnerChannel, undefined);

            done();

        });

        afterEach(function () {
            delete process.env.media_path;
            delete process.env.owner_account;
            delete process.env.channel;
        });
    });

    describe('#getMetadata', function() {

        beforeEach(function () {
            process.env.title = 'title';
            process.env.description = 'description';
            process.env.category_id = 2;
            process.env.access = 'status';
        });

        afterEach(function () {
            delete process.env.title;
            delete process.env.description;
            delete process.env.category_id;
            delete process.env.access;
        });


        it('should parse metadata when all environment variables exist', function(done) {
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

        it('should throw if no title provided', function(done) {
            delete process.env.title;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a title');

            done();
        });

        it('should throw if no description provided', function(done) {
            delete process.env.description;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a description');

            done();
        });

        it('should throw if no category provided', function(done) {
            delete process.env.category_id;

            assert.throws(youtubeUpload.getMetadata, Error, 'Cannot upload to youtube: missing a category id');

            done();
        });

        it('should use default status if no status provided', function(done) {
            delete process.env.access;
            const metadata = youtubeUpload.getMetadata();
            const status = metadata.status.privacyStatus;

            assert.equal(status, 'private');

            done();
        });
    });
});
