import "./utils/dotenvConfig";

/* hardhat plugins */
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "@tenderly/hardhat-tenderly";
import "solidity-coverage";
import "@chainlink/hardhat-chainlink";

import cNetworks from "./constants/cNetworks";
import { HardhatUserConfig } from "hardhat/config";
import "./tasks";
import { getEnvVar } from "./utils";

// const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? process.exit(1);
// const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW";
const enableGasReport = process.env.REPORT_GAS !== "false";

const config: HardhatUserConfig = {
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
    version: "0.8.20",
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
    proxyDeployer: {
      default: 1,
    },
  },
  networks: cNetworks,
  etherscan: {
    apiKey: {
      avalancheFuji: "snowtrace",
      arbitrum: getEnvVar("ARBISCAN_API_KEY"),
      mainnet: getEnvVar("ETHERSCAN_API_KEY"),
      polygon: getEnvVar("POLYGONSCAN_API_KEY"),
      optimism: getEnvVar("OPTIMISM_API_KEY"),
    },
    customChains: [
      {
        network: "optimism",
        chainId: 10,
        urls: {
          apiURL: "https://api-optimistic.etherscan.io/api",
          browserURL: "https://optimistic.etherscan.io/",
        },
      },
      {
        network: "arbitrum",
        chainId: 42161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io/",
        },
      },
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

export default config;
