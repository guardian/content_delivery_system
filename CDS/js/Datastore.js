/* put constructor stuff out here */
var sqlite3 = require('sqlite3');
var Promise = require('promise');

var db = new sqlite3.Database(process.env.cf_datastore_location);

function Connection(whoami) {
    this.whoami=whoami;
}

function getSource(type,myname){
    return new Promise(function(fulfill,reject) {
        var stmt = db.prepare("SELECT id FROM sources WHERE type=? and provider_method=?");
        stmt.get([type, myname], function (err, row) {
            if (err) {
                reject(err);
                return;
            }
            if (row) {
                fulfill(row.id);
                return;
            }
            var new_stmt = db.prepare("INSERT INTO sources (type,provider_method,ctime) values (?,?,?)");
            new_stmt.run([type,myname,Date.now()], function(err){
                if(err) {
                    reject(err);
                } else {
                    fulfill(this.lastID);
                }
            });
        });
    });
}

function get(conn,type, key, callback, userdata) { /* callback as function(err, value) */
    if (type !== "meta" && type !== "media" && type !== "tracks") throw "type must be meta, media or track";
    return new Promise(function (fulfill, reject) {
        getSource(type, conn.whoami).then(function (sourceid) {
            db.serialize(function () {
                var stmt = db.prepare("select value from " + type + " where source_id=? and key=?");
                stmt.get(sourceid, key, function (err, row) {
                    if (err) {
                        console.error(err);
                        reject(err);
                    }
                    if (!row) {
                        reject("no row found with key \'" + key + "\'");
                    } else {
                        //console.log(row);
                        if(callback){
                            fulfill(callback(row.value,userdata));
                        } else {
                            fulfill(row.value);
                        }
                    }
                });
            });
        });
    });
}

module.exports = {
    Connection: Connection,
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
    set: function(conn, type, key, value){
        if(type!=="meta" && type!=="media" && type!=="tracks") throw "type must be meta, media or track";

        return new Promise(function(fulfill,reject) {
            getSource(type,conn.whoami).then(function(sourceid) {
                db.serialize(function () {
                    var stmt = db.prepare("insert into " + type + " (source_id,key,value) values (?,?,?)");
                    stmt.run(sourceid, key, value);
                    stmt.finalize(function (err, row) {
                        if (err) {
                            console.error(err);
                            reject(err);
                        } else {
                            fulfill();
                        }
                    });
                });
            },function(err){
                reject(err);
            });
        });
    },
    get: get,
    substituteString: function(conn,str){
        return new Promise(function(fulfill,reject) {
            var param_matcher = /\{(\w+):([^}]+)\}/g;

            var promiseList=[];
            var matched=0;
            while(matches = param_matcher.exec(str)){
                var matchtext = matches[0]
                var type=matches[1];
                var key=matches[2];
                //console.log(type);
                //console.log(key);

                var promise = get(conn,type,key,function(result,matchtext){
                    //console.log("get promise callback: "+result);
                    return {'find': matchtext, 'replace': result}
                },matchtext);
                promiseList.push(promise);
                ++matched;
            }
            //console.log(promiseList);
            Promise.all(promiseList).done(function(valueList){
                //console.log(valueList);
                for(var i=0;i<valueList.length;++i){
                    //var replacement = new RegExp();
                    console.log("replacing " + valueList[i].find + " with " + valueList[i].replace)
                    str = str.replace(valueList[i].find,valueList[i].replace);
                }
                fulfill(str);
            },function(err){
                reject(err);
            });

            if (matched==0){
                fulfill(str);
            }
        });
    }
};
