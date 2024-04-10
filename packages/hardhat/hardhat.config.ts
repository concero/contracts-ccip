import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import * as dotenv from "dotenv";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";

dotenv.config({ path: "../../.env" });

const { ALCHEMY_API_KEY, INFURA_API_KEY } = process.env;

const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY ?? process.exit(1);
const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "DNXJA8RX2Q3VZ4URQIWP7Z68CJXQZSC6AW";
const enableGasReport = process.env.REPORT_GAS !== "false";

const config: HardhatUserConfig = {
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
        url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
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
    polygonMumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [deployerPrivateKey],
    },
    avalancheFuji: {
      url: `https://avalanche-fuji.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [deployerPrivateKey],
    },
    // mainnet: {
    //   url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // sepolia: {
    //   url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
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
    // arbitrumSepolia: {
    //   url: `https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // optimism: {
    //   url: `https://opt-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [deployerPrivateKey],
    // },
    // optimismSepolia: {
    //   url: `https://opt-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
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
    // baseSepolia: {
    //   url: "https://sepolia.base.org",
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
    apiKey: `${etherscanApiKey}`,
  },
  verify: {
    etherscan: {
      apiKey: `${etherscanApiKey}`,
    },
  },
  sourcify: {
    enabled: false,
  },
  gasReporter: {
    enabled: enableGasReport,
  },
};

export default config;
