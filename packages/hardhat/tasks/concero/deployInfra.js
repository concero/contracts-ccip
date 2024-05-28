"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.liveChains = void 0;
const config_1 = require("hardhat/config");
const fundSubscription_1 = require("./fundSubscription");
const CNetworks_1 = __importDefault(require("../../constants/CNetworks"));
const setContractVariables_1 = require("./setContractVariables");
const fundContract_1 = require("./fundContract");
const log_1 = __importDefault(require("../../utils/log"));
const upload_1 = __importDefault(require("../donSecrets/upload"));
const _02_Concero_1 = __importDefault(require("../../deploy/02_Concero"));
const child_process_1 = require("child_process");
exports.liveChains = [CNetworks_1.default.baseSepolia, CNetworks_1.default.arbitrumSepolia, CNetworks_1.default.optimismSepolia];
let deployableChains = exports.liveChains;
(0, config_1.task)("deploy-infra", "Deploy the CCIP infrastructure")
    .addFlag("skipdeploy", "Deploy the contract to a specific network")
    // .addFlag("all", "Deploy the contract to all networks")
    .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, config_1.types.int)
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;
    // if (taskArgs.all) deployableChains = liveChains;
    // else
    if (name !== "localhost" && name !== "hardhat")
        deployableChains = [CNetworks_1.default[name]];
    if (taskArgs.skipdeploy)
        (0, log_1.default)("Skipping deployment", "deploy-infra");
    else {
        (0, child_process_1.execSync)("yarn compile", { stdio: "inherit" });
        await (0, _02_Concero_1.default)(hre, { slotId });
    }
    await (0, upload_1.default)(deployableChains, slotId, 4320);
    await (0, setContractVariables_1.setContractVariables)(exports.liveChains, deployableChains, slotId);
    await (0, fundSubscription_1.fundSubscription)(exports.liveChains);
    await (0, fundContract_1.fundContract)(deployableChains);
    //todo: allowance of link & BNM
});
exports.default = {};
