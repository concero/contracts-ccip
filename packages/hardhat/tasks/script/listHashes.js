"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const CLFSecrets_1 = __importDefault(require("../../constants/CLFSecrets"));
const getHashSum_1 = __importDefault(require("../../utils/getHashSum"));
(0, config_1.task)("clf-list-hashes", "Lists hashes for JS code").setAction(async (taskArgs) => {
    console.log("SRC:", (0, getHashSum_1.default)(CLFSecrets_1.default.SRC_JS));
    console.log("DST:", (0, getHashSum_1.default)(CLFSecrets_1.default.DST_JS));
});
exports.default = {};
