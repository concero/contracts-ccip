import * as dotenv from "dotenv";

dotenv.config({ path: "../../.env" });
dotenv.config({ path: "../../.env.chainlink" });
dotenv.config({ path: "../../.env.tokens" });

import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
import "@chainlink/hardhat-chainlink";
import * as tdly from "@tenderly/hardhat-tenderly";
import rpc from "./constants/rpcUrls";

import "./tasks";

const { ALCHEMY_API_KEY, INFURA_API_KEY } = process.env;
// task("deployConsumer", "Deploys the FunctionsConsumer contract")
//   .addOptionalParam("verify", "Set to true to verify contract", false, types.boolean)
//   .setAction(async (hardhat, taskArgs) => {
//     await deployCLFConsumer(hardhat, taskArgs);
//   });

const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? process.exit(1);
const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW";
const enableGasReport = process.env.REPORT_GAS !== "false";

// tdly.setup();

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
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: rpc.mainnet,
        enabled: process.env.MAINNET_FORKING_ENABLED === "true",
        blockNumber: 9_675_000,
      },
      accounts: [
        {
          privateKey: deployerPrivateKey,
          balance: "10000000000000000000000",
        },
        {
          privateKey: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
          balance: "10000000000000000000000",
        },
      ],
    },
    // TESTNETS
    sepolia: {
      url: rpc.sepolia,
      accounts: [deployerPrivateKey],
    },
    avalancheFuji: {
      chainId: 43113,
      url: rpc.avalancheFuji,
      accounts: [deployerPrivateKey],
    },
    optimismSepolia: {
      url: rpc.optimismSepolia,
      accounts: [deployerPrivateKey],
    },
    arbitrumSepolia: {
      url: rpc.arbitrumSepolia,
      accounts: [deployerPrivateKey],
    },
    baseSepolia: {
      url: rpc.baseSepolia,
      accounts: [deployerPrivateKey],
    },
    // MAINNETS
    // mainnet: {
    //   url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // goerli: {
    //   url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // arbitrum: {
    //   url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // optimism: {
    //   url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // polygon: {
    //   url: `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // polygonZkEvm: {
    //   url: `https://polygonzkevm-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // polygonZkEvmTestnet: {
    //   url: `https://polygonzkevm-testnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // gnosis: {
    //   url: "https://rpc.gnosischain.com",
    //   accounts: [deployerPrivateKey],
    // },
    // chiado: {
    //   url: "https://rpc.chiadochain.net",
    //   accounts: [deployerPrivateKey],
    // },
    // base: {
    //   url: "https://mainnet.base.org",
    //   accounts: [deployerPrivateKey],
    // },
    // baseGoerli: {
    //   url: "https://goerli.base.org",
    //   accounts: [deployerPrivateKey],
    // },
    // scrollSepolia: {
    //   url: "https://sepolia-rpc.scroll.io",
    //   accounts: [deployerPrivateKey],
    // },
    // scroll: {
    //   url: "https://rpc.scroll.io",
    //   accounts: [deployerPrivateKey],
    // },
    // pgn: {
    //   url: "https://rpc.publicgoods.network",
    //   accounts: [deployerPrivateKey],
    // },
    // pgnTestnet: {
    //   url: "https://sepolia.publicgoods.network",
    //   accounts: [deployerPrivateKey],
    // },
  },
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
