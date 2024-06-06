"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("./utils/dotenvConfig");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-viem");
require("@nomicfoundation/hardhat-verify");
require("@typechain/hardhat");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-gas-reporter");
// import "hardhat-change-network";
require("hardhat-contract-sizer");
require("solidity-coverage");
require("@chainlink/hardhat-chainlink");
const CNetworks_2 = __importDefault(require("./constants/CNetworks"));
require("./tasks");
const hardhat_tenderly_1 = require("@tenderly/hardhat-tenderly");
// const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? process.exit(1);
// const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW";
const enableGasReport = process.env.REPORT_GAS !== "false";
(0, hardhat_tenderly_1.setup)();
const config = {
    tenderly: {
        username: "olegkron",
        project: "own",
    },
    paths: {
        artifacts: "artifacts",
        cache: "cache",
        sources: "contracts",
        tests: "test",
    },
    solidity: {
        version: "0.8.19",
        settings: {
            // evmVersion: "paris",
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    defaultNetwork: "localhost",
    namedAccounts: {
        deployer: {
            default: 0,
        },
        nikita: {
            default: 1,
        },
    },
    networks: CNetworks_2.default,
    etherscan: {
        apiKey: {
            avalancheFuji: "snowtrace",
        },
        customChains: [
            {
                network: "avalancheFuji",
                chainId: 43114,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
                    browserURL: "https://snowtrace.io",
                },
            },
        ],
    },
    // verify: {
    //   etherscan: {
    //     apiKey: `${etherscanApiKey}`,
    //   },
    // },
    sourcify: {
        enabled: false,
    },
    gasReporter: {
        enabled: enableGasReport,
    },
};
exports.default = config;
