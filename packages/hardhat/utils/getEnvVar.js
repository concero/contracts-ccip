"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getEnvVar = void 0;
const process_1 = __importDefault(require("process"));
function getEnvVar(key) {
    const value = process_1.default.env[key];
    if (value === undefined)
        throw new Error(`Missing required environment variable ${key}`);
    if (value === "")
        throw new Error(`${key} must not be empty`);
    return value;
}
exports.getEnvVar = getEnvVar;
