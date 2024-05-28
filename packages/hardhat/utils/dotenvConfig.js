"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reloadDotEnv = void 0;
const dotenv = __importStar(require("dotenv"));
const fs_1 = __importDefault(require("fs"));
const ENV_FILES = [".env", ".env.clf", ".env.clccip", ".env.tokens", ".env.deployments"];
/**
 * Configures the dotenv with paths relative to a base directory.
 * @param {string} [basePath='../../../'] - The base path where .env files are located. Defaults to '../../'.
 */
function configureDotEnv(basePath = "../../") {
    const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;
    ENV_FILES.forEach(file => {
        dotenv.config({ path: `${normalizedBasePath}${file}` });
    });
}
configureDotEnv();
function reloadDotEnv(basePath = "../../") {
    const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;
    ENV_FILES.forEach(file => {
        const fullPath = `${normalizedBasePath}${file}`;
        const currentEnv = dotenv.parse(fs_1.default.readFileSync(fullPath));
        Object.keys(currentEnv).forEach(key => {
            delete process.env[key];
        });
        dotenv.config({ path: fullPath });
    });
}
exports.reloadDotEnv = reloadDotEnv;
exports.default = configureDotEnv;
