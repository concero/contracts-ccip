import "./utils/dotenvConfig";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
// import "hardhat-change-network";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
import "@chainlink/hardhat-chainlink";
import CNetworks from "./constants/CNetworks";
import "./tasks";
import { setup as setupTenderly } from "@tenderly/hardhat-tenderly";

// const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? process.exit(1);
// const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW";
const enableGasReport = process.env.REPORT_GAS !== "false";

setupTenderly();

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
  networks: CNetworks,
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

export default config;
