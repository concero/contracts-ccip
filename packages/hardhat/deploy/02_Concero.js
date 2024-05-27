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
const CNetworks_1 = __importStar(require("../constants/CNetworks"));
const updateEnvVariable_1 = __importDefault(require("../utils/updateEnvVariable"));
const add_1 = __importDefault(require("../tasks/sub/add"));
const log_1 = __importDefault(require("../utils/log"));
const CLFSecrets_1 = __importDefault(require("../constants/CLFSecrets"));
const getHashSum_1 = __importDefault(require("../utils/getHashSum"));
/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConcero = async function (hre, constructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name } = hre.network;
    if (!CNetworks_1.default[name])
        throw new Error(`Chain ${name} not supported`);
    const { functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds, chainSelector, conceroChainIndex, linkToken, ccipRouter, priceFeed, } = CNetworks_1.default[name];
    const defaultArgs = {
        slotId: 0,
        functionsRouter: functionsRouter,
        donHostedSecretsVersion: donHostedSecretsVersion,
        functionsDonId: functionsDonId,
        functionsSubId: functionsSubIds[0],
        chainSelector: chainSelector,
        conceroChainIndex: conceroChainIndex,
        linkToken: linkToken,
        ccipRouter: ccipRouter,
        priceFeed: priceFeed,
        jsCodeHashSum: {
            src: (0, getHashSum_1.default)(CLFSecrets_1.default.SRC_JS),
            dst: (0, getHashSum_1.default)(CLFSecrets_1.default.DST_JS),
        },
    };
    // Merge defaultArgs with constructorArgs
    const args = { ...defaultArgs, ...constructorArgs };
    const deployment = (await deploy("Concero", {
        from: deployer,
        log: true,
        args: [
            args.functionsRouter,
            args.donHostedSecretsVersion,
            args.functionsDonId,
            args.slotId,
            args.functionsSubId,
            args.chainSelector,
            args.conceroChainIndex,
            args.linkToken,
            args.ccipRouter,
            args.priceFeed,
            args.jsCodeHashSum,
        ],
        autoMine: true,
    }));
    if (name !== "hardhat" && name !== "localhost") {
        (0, log_1.default)(`Contract Concero deployed to ${name} at ${deployment.address}`, "deployConcero");
        (0, updateEnvVariable_1.default)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[name]}`, deployment.address, "../../../.env.deployments");
        await (0, add_1.default)(CNetworks_1.default[name], [deployment.address], args.functionsSubId);
    }
};
exports.default = deployConcero;
deployConcero.tags = ["Concero"];
