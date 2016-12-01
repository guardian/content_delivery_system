/* put constructor stuff out here */
const sqlite3 = require('sqlite3');
const fs = require('fs');
const Promise = require('promise');
const defaultLocalDefinitionsPath="/etc/cds_backend/conf.d";

var db;

function Connection(whoami, path) {

    db = new sqlite3.Database(process.env.cf_datastore_location);
    this.whoami=whoami;
    if(path){
        this.configDefs=loadDefs(path);
    } else {
        this.configDefs=loadDefs(defaultLocalDefinitionsPath);
    }
}

function loadDefs(path) {

    let file_list;
    try {
        file_list = fs.readdirSync(path);
    } catch(e){
        return {};
    }
    const is_comment = /^#/;
    const matcher = /^(\w+)\s*=\s*(.*)$/;

    //Take each file and concatenate lines into single array
    const data_lines = file_list.reduce((lines, currentFile) => {
        var data = fs.readFileSync(path + "/" + currentFile,'utf8');
        return lines.concat(data.split("\n"))
    }, []);

    //Filter any lines that aren't valid
    const filteredLines = data_lines
        .filter(line => line.length > 3) //shortest valid config line is 'a=b', 3 chars
        .filter(line => !is_comment.test(line));

    //Combine into single Key Value Object
    return filteredLines.reduce((definitions, currentLine) => {
        const matches = matcher.exec(currentLine);
        if (matches) {
            const matchObject = {};
            matchObject[matches[1]] = matches[2];
            return Object.assign({}, definitions, matchObject) ;
        } else {
            console.error("line " + currentLine + " is not valid");
            return definitions;
        }
    }, {});
}

function getSource(type,myname){
    return new Promise(function(fulfill,reject) {
        var stmt = db.prepare("SELECT id FROM sources WHERE type=? and provider_method=?");
        stmt.get([type, myname], function (err, row) {
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
            const stmt = db.prepare("insert into " + type + " (source_id,key,value) values (?,?,?)");
            db.serialize(function () {
                const promises = Object.keys(meta).map(key => new Promise(function(innerFulfill,innerReject)
                    {
                        stmt.run(sourceid, key, meta[key], function (err) {
                            if (err) {
                                console.error(err);
                                innerReject(err);
                            } else {
                                innerFulfill();
                            }
                        });
                    })
                );
                Promise.all(promises).then(function(completedResult){
                    fulfill();
                }, function(failedResult){
                    reject(failedResult);
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
                var stmt = db.prepare("select value from " + type + " where key=?");
                stmt.get(key, function (err, row) {
                    if (err) {
                        console.error(err);
                        reject(err);
                    }
                    var rtn;
                    if (!row) {
                        rtn = {value: "(value not found)",type: type,key: key};
                    } else {
                        rtn = {value: row.value,type: type,key: key}
                    }

                    if(callback){
                        fulfill(callback(rtn.value, rtn.type, rtn.key, userdata));
                    } else {
                        fulfill(rtn);
                    }
                });
            });
        });
    });
}

function substituteString(conn,str){
    return new Promise(function(fulfill,reject) {

        function replaceAllOccurances(string, matchText, replacementValue) {

            if (!string) {
                return string;
            }

            //This replaces all occurances of matchText (by splitting) then replaces then with the value (by joining)
            const sanitisedReplacement = replacementValue ? replacementValue : "undefined";
            return string.split(matchText).join(sanitisedReplacement);
        }

        function performStaticSubstitutions(str) {
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

            return Object.keys(static_subs).reduce((currentString, staticSubKey) => {
                return replaceAllOccurances(currentString, staticSubKey, static_subs[staticSubKey])
            }, str)
        }

        function performConfigSubstitutions(str) {
            if(!conn.configDefs) return str;
            return Object.keys(conn.configDefs).reduce((currentString, currentDef) => {
                const matchText = "{config:" + currentDef + "}";
                return replaceAllOccurances(currentString, matchText, conn.configDefs[currentDef] )
            }, str);
        }

        str = performStaticSubstitutions(str);
        str = performConfigSubstitutions(str);


        /* Perform the Async Datastore Replacements */
        var promiseList = [];
        var param_matcher = /\{(\w+):([^}]+)\}/g;

        while(matches = param_matcher.exec(str)){ var matchtext = matches[0];
            var type=matches[1];
            var key=matches[2];

            if(type !== 'config') {
                promiseList.push(get(conn, type, key, function (result, type, key, matchtext) {
                    return {'find': matchtext, 'replace': result}
                }, matchtext));
            } else {
                promiseList.push(new Promise((fulfill, reject) => {
                    fulfill({'find': matchtext, 'replace': "(value not found)"});
                }));
            }
        }

        Promise.all(promiseList).done(function(replacementsList){
            const returnString = replacementsList.reduce((currentString, replacementObj) => {
                return replaceAllOccurances(currentString, replacementObj.find, replacementObj.replace);
            }, str);
            fulfill(returnString);
        },function(err){
            reject(err);
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
    substituteString: substituteString,
    substituteStrings: function(conn, strs) {
        return Promise.all(strs.map((str) => this.substituteString(conn, str)));
    }
};
