/* put constructor stuff out here */
const sqlite3 = require('sqlite3');
const fs = require('fs');
const Promise = require('promise');
const defaultLocalDefinitionsPath="/etc/cds_backend/conf.d";

var db = new sqlite3.Database(process.env.cf_datastore_location);

function Connection(whoami, path) {
    this.whoami=whoami;
    if(path){
        this.staticDefs=loadDefs(path);
    } else {
        this.staticDefs=loadDefs(defaultLocalDefinitionsPath);
    }
    //console.log(this.staticDefs);
}

function loadDefs(path) {
    const file_list = fs.readdirSync(path);
    const is_comment = /^#/;
    const matcher = /^(\w+)\s*=\s*(.*)$/;
    rtn = {};
    for(var i=0;i<file_list.length;++i){
        //console.log("loadDefs: reading file " + file_list[i]);
        var data = fs.readFileSync(path + "/" + file_list[i],'utf8');
        var data_lines = data.split("\n");

        for(var l=0;l<data_lines.length;++l){
            //console.log(data_lines[l]);
            if(is_comment.test(data_lines[l])) continue;
            if(data_lines[l].length<3) continue; //shortest valid config line is 'a=b', 3 chars
            matches = matcher.exec(data_lines[l]);
            if(matches){
                rtn[matches[1]] = matches[2];
            } else {
                console.error("line " + l + "(" + data_lines[l] + ") in " + file_list[i] + " does not match");
            }
        }
    }
    return rtn;
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
            new_stmt.run([type,myname,Math.floor(Date.now())], function(err){
                if(err) {
                    reject(err);
                } else {
                    fulfill(this.lastID);
                }
            });
        });
    });
}

function setMulti(conn, type, meta){
    if(type!=="meta" && type!=="media" && type!=="tracks") throw "type must be meta, media or track";

    return new Promise(function(fulfill,reject) {
        getSource(type,conn.whoami).then(function(sourceid) {
            var promises = [];
            db.serialize(function () {
                Object.keys(meta).forEach(function (key) {
                    //console.log(key + " => " + meta[key]);
                    var stmt = db.prepare("insert into " + type + " (source_id,key,value) values (?,?,?)");
                    stmt.run(sourceid, key, meta[key], function (err) {
                        if (err) {
                            console.error(err);
                            reject(err);
                        } else {
                            fulfill();
                        }
                    });
                });
            });
        },function(err){
            reject(err);
        });
    });
}

function set(conn, type, key, value) {
    return setMulti(conn,type,{[key]: value});
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
                        //reject("no row found with key \'" + key + "\'");
                        fulfill({value: "(value not found)",type: type,key: key});
                    } else {
                        //console.log(row);
                        if(callback){
                            fulfill(callback(row.value,type,key,userdata));
                        } else {
                            fulfill({value: row.value,type: type,key: key});
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
    set: set,
    setMulti: setMulti,
    get: get,
    substituteString: function(conn,str){
        return new Promise(function(fulfill,reject) {
            /* setup */
            const d = new Date();
            const static_subs = {
                '{route-name}': process.env.cf_route_name,
                '{hostname}': process.env.HOSTNAME,
                '{ostype}': process.env.OSTYPE,
                '{year}': d.getFullYear(),
                '{month}': d.getMonth()+1,
                '{day}': d.getDay(),
                '{hour}': d.getHours(),
                '{min}': d.getMinutes(),
                '{sec}': d.getSeconds()
            };

            var promiseList=[];
            var matched=0;

            /* first, perform static substitutions */
            Object.keys(static_subs).forEach(function(key){
                //console.log("checking " + key + "(=>" + static_subs[key] + ") against " + str);
                const matcher = new RegExp(key,'gi');
                while(matches = matcher.exec(str)){
                    //console.log(matches);
                    var promise = new Promise(function(fulfill,reject){
                        //console.log("subbing " + static_subs[key] + " for " + key);
                        fulfill({find: key,replace: static_subs[key]});
                    });
                    promiseList.push(promise);
                    ++matched;
                }
            });


            /* finally, perform datastore substitutions */
            var param_matcher = /\{(\w+):([^}]+)\}/g;

            while(matches = param_matcher.exec(str)){
                var matchtext = matches[0];
                var type=matches[1];
                var key=matches[2];

                if(type=='config') {
                    promiseList.push(new Promise(function (fulfill, reject) {
                        if (conn.staticDefs[key]) {
                            fulfill({find: matchtext, replace: conn.staticDefs[key]});
                        } else {
                            fulfill({find: matchtext, replace: "(value not found)"});
                        }
                    }));
                } else {
                    promiseList.push(get(conn, type, key, function (result, type, key, matchtext) {
                        return {'find': matchtext, 'replace': result}
                    }, matchtext));
                }
                ++matched;
            }
            //console.log(promiseList);
            Promise.all(promiseList).done(function(valueList){
                //console.log(valueList);
                for(var i=0;i<valueList.length;++i){
                    //var replacement = new RegExp();
                    //console.log("replacing " + valueList[i].find + " with " + valueList[i].replace);
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
