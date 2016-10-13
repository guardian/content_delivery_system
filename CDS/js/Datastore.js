/* put constructor stuff out here */
var sqlite3 = require('sqlite3');
var Promise = require('promise');

var db = new sqlite3.Database(process.env.cf_datastore_location);


module.exports = {
    newDataStore: function() {
        return new Promise(function(fulfill, reject) {
            db.serialize(function () {
                db.parallelize(function () {
                    db.run("CREATE TABLE sources (id integer primary key autoincrement,type,provider_method,ctime,filename,filepath)");
                    db.run("CREATE TABLE meta (id integer primary key autoincrement,source_id,key,value)");
                    db.run("CREATE TABLE system (schema_version,cds_version)");
                    db.run("CREATE TABLE tracks (id integer primary key autoincrement,source_id,track_index,key,value)");
                    db.run("CREATE TABLE media (id integer primary key autoincrement,source_id,key,value)");
                });
                db.run("INSERT INTO system (schema_version,cds_version) VALUES (1.0,3.0)", function(err){
                    if(!err) {
                        fulfill(this.lastID);
                    } else {
                        console.error(err);
                        reject(err);
                    }
                });
            });
        });
    },
    close: function() {
        db.close();
    },
    loadDefs: function(){

    },
    set: function(type, key, value){
        if(type!=="meta" && type!=="media" && type!=="tracks") throw "type must be meta, media or track";

        return new Promise(function(fulfill,reject) {
            db.serialize(function () {
                var stmt = db.prepare("insert into " + type + " (source_id,key,value) values (?,?,?)");
                stmt.run(0, key, value);
                stmt.finalize(function (err, row) {
                    if(err){
                        console.error(err);
                        reject(err);
                    } else {
                        fulfill();
                    }
                });
            });
        });
    },
    get: function(type, key){ /* callback as function(err, value) */
        if(type!=="meta" && type!=="media" && type!=="tracks") throw "type must be meta, media or track";
        return new Promise(function(fulfill,reject) {
            db.serialize(function() {
                var stmt = db.prepare("select value from "+type+" where source_id=? and key=?");
                stmt.get([0, key], function (err, row) {
                    if(err) {
                        console.error(err);
                        reject(err);
                    } if(!row){
                        reject("no row found with key \'"+ key+"\'");
                    } else {
                        console.log(row);
                        fulfill(row.value);
                    }
                });
            });
        });
    },
    substituteString: function(str){

    }
};

/*
{min}
{meta:keyname}
{media:keyname}
{track:1:keyname}
{config:}
*/