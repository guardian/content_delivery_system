#!/usr/bin/env node

const youtubeLib = require('./youtube-upload-lib');

youtubeLib.uploadToYoutube()
.then(function(response) {
    console.log('+SUCCESS: Video with title ', response.snippet.title, 'was uploaded to Youtube succesfully with id ', response.id);
    if (process.env.debug) {
        console.log('data returned from youtube ', response);
    }

    process.exit();

}).catch(function(err) {
    console.log('-ERROR in uploading to youtube ', err);
    process.exit(1);
});

