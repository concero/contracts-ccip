"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fs_1 = require("fs");
const path_1 = __importDefault(require("path"));
const log_1 = __importDefault(require("./log"));
/**
 * Update an environment variable in the .env file
 * @param key The key of the environment variable to update
 * @param newValue The new value of the environment variable
 * @param envPath The path to the .env file
 * usage: // updateEnvVariable("CLF_DON_SECRETS_VERSION_SEPOLIA", "1712841283", "../../../.env.clf");
 */
function updateEnvVariable(key, newValue, envPath = "../../../.env") {
    const filePath = path_1.default.join(__dirname, envPath);
    if (!filePath)
        throw new Error(`File not found: ${filePath}`);
    const envContents = (0, fs_1.readFileSync)(filePath, "utf8");
    let lines = envContents.split(/\r?\n/);
    if (!lines.some(line => line.startsWith(`${key}=`))) {
        (0, log_1.default)(`Key ${key} not found in .env file. Adding to ${filePath}`, "updateEnvVariable");
        lines.push(`${key}=${newValue}`);
    }
    const newLines = lines.map(line => {
        let [currentKey, currentValue] = line.split("=");
        if (currentKey === key) {
            return `${key}=${newValue}`;
        }
        return line;
    });
    (0, fs_1.writeFileSync)(filePath, newLines.join("\n"));
    process.env[key] = newValue;
}
exports.default = updateEnvVariable;
