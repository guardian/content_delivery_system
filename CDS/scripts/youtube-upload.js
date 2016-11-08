#!/usr/bin/env node

//This method uploads the video specified in the cnf_media_file parameter to youtube.
//It expects the following arguments:
//<client_secrets> - path to the client secrets file with client id, client secret and client email
//<private_key> path to encrypted private key file
//<passphrase> passphrase for the key file
//<category_id> - the category id for the video
//<access> - the level of access for the video
//<owner_channel> - [OPTIONAL] the channel you are uploading to
//<owner_account> - [OPTIONAL] The account that the video is uploaded on behalf of. You can ommit the channel and owner_account parameters, but this means you cannot upload videos of accounts with multiple channels. If you specify the channel to upload to, then you must also specify the owner account you are uploading on behalf of.

var youtubeLib = require('../js/youtube/youtube-upload-lib');
var dataStore = require('../js/Datastore');

var connection = new dataStore.Connection("youtube-upload.js");

youtubeLib.uploadToYoutube(connection)
.then(response => {
    console.log('+SUCCESS: Video with title ', response.snippet.title, 'was uploaded to Youtube succesfully with id ', response.id);
    if (process.env.debug) {
        console.log('data returned from youtube ', response);
    }

    process.exit();

}).catch(err => {
    console.log('-ERROR in uploading to youtube ', err);
    process.exit(1);
});

