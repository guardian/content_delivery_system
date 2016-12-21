class Logger {
    static info (message) {
        console.info(`INFO - ${message}`);
    }

    static error (message) {
        console.error(`ERROR - ${message}`);
    }
}

module.exports = Logger;