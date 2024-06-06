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
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
const envfile_1 = require("envfile");
const fs = __importStar(require("fs"));
const envFilePath = "./.env";
/**
 * Generate a new random private key and write it to the .env file
 */
const setNewEnvConfig = (existingEnvConfig = {}) => {
    console.log("👛 Generating new Wallet");
    const randomWallet = ethers_1.ethers.Wallet.createRandom();
    const newEnvConfig = {
        ...existingEnvConfig,
        DEPLOYER_PRIVATE_KEY: randomWallet.privateKey,
    };
    // Store in .env
    fs.writeFileSync(envFilePath, (0, envfile_1.stringify)(newEnvConfig));
    console.log("📄 Private Key saved to packages/hardhat/.env file");
    console.log("🪄 Generated wallet address:", randomWallet.address);
};
async function main() {
    if (!fs.existsSync(envFilePath)) {
        // No .env file yet.
        setNewEnvConfig();
        return;
    }
    // .env file exists
    const existingEnvConfig = (0, envfile_1.parse)(fs.readFileSync(envFilePath).toString());
    if (existingEnvConfig.DEPLOYER_PRIVATE_KEY) {
        console.log("⚠️ You already have a deployer account. Check the packages/hardhat/.env file");
        return;
    }
    setNewEnvConfig(existingEnvConfig);
}
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
