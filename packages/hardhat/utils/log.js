"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function log(message, functionName) {
    const greenFill = "\x1b[42m";
    const reset = "\x1b[0m";
    console.log(`${greenFill}[${functionName}]${reset}`, message);
}
exports.default = log;
