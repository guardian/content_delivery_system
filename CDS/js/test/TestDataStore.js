var assert = require('assert');
const fs = require('fs');

process.env.cf_datastore_location='./test.db';
fs.unlink(process.env.cf_datastore_location);
var datastore = require('../Datastore');

describe('Datastore',function(){
       before(function(done){
           datastore.newDataStore().then(function(){
               done();
           });
       });


    after(function(){
        fs.unlink(process.env.cf_datastore_location);
    });

    describe('#set', function(){
        it('should store a value to meta and return nothing', function(done){
            datastore.set('meta','key','something').done(function(value){
                done();
            },function(err){
                //console.error(err);
                done(err);
            })
        });
        it('should store a value to media and return nothing', function(){
            assert.doesNotThrow(function(){
                datastore.set('media','mediaKey','somethingElse');
            });
        });
    });
    describe('#get', function(){
        it('should return the previously set value from meta', function(test_completed) {
            datastore.get('meta','key').done(function(value){
                assert.equal(value,'something');
                test_completed();
            }, function(err){
                test_completed(err);
            });

        });
        it('should return the previously set value from media', function(test_completed) {
            datastore.get('media','mediaKey').done(function(value){
                assert.equal(value,'somethingElse');
                test_completed();
            }, function(err){
                //console.error(err);
                test_completed(err);
            });

        });
        // it('should return the previously set value from media', function(){
        //     assert.equal(datastore.get('media','mediaKey'),'somethingElse');
        // });
    });
    describe('#substituteString',function(){
       it('should not modify a string without braces in', function(){

       });
        it('should substitute {hour}:{min} for the current time', function(){

        });
        it('should substitute a value for {meta:key}', function () {

        });
        it('should substitute placeholder for {meta:undefinedkey}', function() {

        });
    });
});