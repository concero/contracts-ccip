"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deployContract = void 0;
const child_process_1 = require("child_process");
const dotenvConfig_1 = require("../../utils/dotenvConfig");
const log_1 = __importDefault(require("../../utils/log"));
async function deployContract(chains, hre) {
    (0, log_1.default)(`Deploying infra to ${chains.map(c => c.name).join(", ")}`, "deploy-infra");
    for (const chain of chains) {
        (0, child_process_1.execSync)(`bunx hardhat deploy --network ${chain.name} --tags Concero`, { stdio: "inherit" });
    }
    (0, dotenvConfig_1.reloadDotEnv)();
}
exports.deployContract = deployContract;
