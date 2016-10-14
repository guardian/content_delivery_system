var assert = require('assert');
const fs = require('fs');
const mkpath = require('mkpath');

const test_data_dir = "/tmp/cdstest/conf.d";
process.env.cf_datastore_location='./test.db';
if(fs.existsSync(process.env.cf_datastore_location))
    fs.unlink(process.env.cf_datastore_location);
var datastore = require('../Datastore');

describe('Datastore',function(){
    var conn;

       before(function(done){
           mkpath.sync(test_data_dir+"/",0o777);
           fs.writeFileSync(test_data_dir + "/file01.conf","file01_key_01=data\n#file01 commnt line = stuff\n\nfile01_key_02 = data02\n","utf8");
           fs.writeFileSync(test_data_dir + "/file02.conf","#file02 commnt line = stuff\n\nfile02_key_01=thing\nfile02_key_02 = ribbit\n","utf8");
           datastore.newDataStore().then(function(value){
               conn=new datastore.Connection("TestDataStore",test_data_dir);
               done();
           }, function(err){
               done(err);
           });
       });


    after(function(){
        fs.unlink(process.env.cf_datastore_location);
    });

    describe('#set', function(){
        it('should store a value to meta and return nothing', function(done){
            datastore.set(conn,'meta','key','something').done(function(value){
                done();
            },function(err){
                //console.error(err);
                done(err);
            })
        });
        it('should store a value to media and return nothing', function(){
            assert.doesNotThrow(function(){
                datastore.set(conn,'media','mediaKey','somethingElse');
            });
        });

    });
    describe('#get', function(){
        it('should return the previously set value from meta', function(test_completed) {
            datastore.get(conn,'meta','key').done(function(rtn){
                assert.equal(rtn.value,'something');
                assert.equal(rtn.type,'meta');
                assert.equal(rtn.key,'key');
                test_completed();
            }, function(err){
                test_completed(err);
            });

        });
        it('should return the previously set value from media', function(test_completed) {
            datastore.get(conn,'media','mediaKey').done(function(rtn){
                assert.equal(rtn.value,'somethingElse');
                assert.equal(rtn.type,'media');
                assert.equal(rtn.key,'mediaKey');
                test_completed();
            }, function(err){
                //console.error(err);
                test_completed(err);
            });

        });
        it('should return placeholder text for an unknown key', function(test_completed) {
            datastore.get(conn,'meta','unknownkey').done(function(rtn){
                assert.equal(rtn.value,'(value not found)');
                assert.equal(rtn.type,'meta');
                assert.equal(rtn.key,'unknownkey');
                test_completed();
            }, function(err){
                test_completed(err);
            });
        });
        // it('should return the previously set value from media', function(){
        //     assert.equal(datastore.get('media','mediaKey'),'somethingElse');
        // });
    });
    describe('#substituteString',function(){
       it('should not modify a string without braces in', function(test_completed){
            datastore.substituteString(conn,"test string with no braces").done(function(value){
               assert.equal(value,"test string with no braces");
                test_completed();
           }, function(err){
                test_completed(err);
            });
       });
        it('should substitute {hour}:{min} for the current time', function(test_completed){
            datastore.substituteString(conn,"{hour}:{min}").done(function(value){
                const d = new Date();
                assert.equal(value,d.getHours() + ":" + d.getMinutes());
                test_completed();
            }, function(err){
                test_completed(err);
            })
        });
        it('should substitute {year}/{month}/{day} for the current date', function(test_completed){
            datastore.substituteString(conn,"{year}/{month}/{day}").done(function(value){
                const d = new Date();
                assert.equal(value,d.getFullYear() + "/" + (d.getMonth()+1) + "/" + d.getDay());
                test_completed();
            }, function(err){
                test_completed(err);
            })
        });
        it('should substitute config file data for {config:file01_key_01} and similar', function(test_completed){
           datastore.substituteString(conn,"{config:file01_key_01};{config:file02_key_02}").done(function(value){
               assert.equal(value,"data;ribbit");
               test_completed();
           },function(err){
               test_completed(err);
           });
        });
        it('should substitute placeholder for {config:unknownkey} and similar', function(test_completed){
            datastore.substituteString(conn,"{config:bababa};{config:file02_key_02}").done(function(value){
                assert.equal(value,"(value not found);ribbit");
                test_completed();
            },function(err){
                test_completed(err);
            });
        });
        it('should substitute a value for {meta:key}', function (test_completed) {
            datastore.substituteString(conn,"I have a {meta:key} with {media:mediaKey}").done(function(value){
                assert.equal(value,"I have a something with somethingElse");
                test_completed();
            }, function(err){
                test_completed(err);
            });
        });
        it('should substitute hostname for  {hostname}', function (test_completed) {
            datastore.substituteString(conn,"I am {hostname}").done(function(value){
                assert.equal(value,"I am " + process.env.HOSTNAME);
                test_completed();
            }, function(err){
                test_completed(err);
            });
        });
        it('should substitute placeholder for {meta:undefinedkey}', function() {
            datastore.substituteString(conn,"I have a {meta:undefinedkey}").done(function(value){
                assert.equal(value,"I have a (value not found)");
                test_completed();
            }, function(err){
                test_completed(err);
            });
        });

    });
});
