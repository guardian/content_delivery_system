/* eslint-disable no-console */

const chalk = require('chalk');

class Logger {
    static info (message) {
        if (process.env.STAGE !== 'test') {
            console.info(chalk.yellow(`INFO - ${message}`));
        }
    }

    static error (message) {
        if (process.env.STAGE !== 'test') {
            console.error(chalk.red(`ERROR - ${message}`));
        }
    }
}

module.exports = Logger;