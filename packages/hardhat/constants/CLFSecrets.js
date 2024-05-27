"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fs_1 = __importDefault(require("fs"));
const build_1 = require("../tasks/script/build");
const log_1 = __importDefault(require("../utils/log"));
const path_1 = __importDefault(require("path"));
const jsPath = "./tasks/CLFScripts";
const secrets = {
    WALLET_PRIVATE_KEY: process.env.MESSENGER_WALLET_PRIVATE_KEY,
    INFURA_API_KEY: process.env.INFURA_API_KEY,
    ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
    SRC_JS: getJS(jsPath, "SRC"),
    DST_JS: getJS(jsPath, "DST"),
};
exports.default = secrets;
function getJS(jsPath, type) {
    const source = path_1.default.join(jsPath, "src", `${type}.js`);
    const dist = path_1.default.join(jsPath, "dist", `${type}.min.js`);
    if (!fs_1.default.existsSync(dist)) {
        (0, log_1.default)(`File not found: ${dist}, building...`, "getJS");
        (0, build_1.buildScript)(source);
    }
    return fs_1.default.readFileSync(dist, "utf8");
}
