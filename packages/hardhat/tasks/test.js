"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const CLFSecrets_1 = __importDefault(require("../constants/CLFSecrets"));
function getHashSum(sourceCode) {
    const hash = require("crypto").createHash("sha256");
    hash.update(sourceCode, "utf8");
    return hash.digest("hex");
}
(0, config_1.task)("test-script", "A test script").setAction(async (taskArgs) => {
    const hashsum = getHashSum(CLFSecrets_1.default.SRC_JS);
    console.log(hashsum);
});
exports.default = {};
