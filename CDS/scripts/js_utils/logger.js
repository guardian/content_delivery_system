class Logger {
    static info (message) {
        if (process.env.STAGE !== 'test') {
            console.info(`INFO - ${message}`);
        }
    }

    static error (message) {
        if (process.env.STAGE !== 'test') {
            console.error(`ERROR - ${message}`);
        }
    }
}

module.exports = Logger;