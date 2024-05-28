"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.functionsGatewayUrls = exports.networkEnvKeys = void 0;
const chains_1 = require("viem/chains");
const DEFAULT_BLOCK_CONFIRMATIONS = 2;
const deployerPK = process.env.DEPLOYER_PRIVATE_KEY;
if (!deployerPK) {
    throw new Error("DEPLOYER_PRIVATE_KEY is not set");
}
exports.networkEnvKeys = {
    // mainnets
    mainnet: "MAINNET",
    arbitrum: "ARBITRUM",
    optimism: "OPTIMISM",
    polygon: "POLYGON",
    polygonZkEvm: "POLYGON_ZKEVM",
    avalanche: "AVALANCHE",
    base: "BASE",
    // testnets
    sepolia: "SEPOLIA",
    optimismSepolia: "OPTIMISM_SEPOLIA",
    arbitrumSepolia: "ARBITRUM_SEPOLIA",
    avalancheFuji: "FUJI",
    baseSepolia: "BASE_SEPOLIA",
};
exports.functionsGatewayUrls = {
    mainnet: ["https://01.functions-gateway.chain.link/", "https://02.functions-gateway.chain.link/"],
    testnet: ["https://01.functions-gateway.testnet.chain.link/", "https://02.functions-gateway.testnet.chain.link/"],
};
const CNetworks = {
    localhost: {
        accounts: [deployerPK],
        // mock CLF data
        functionsDonId: process.env.CLF_DONID_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
    },
    hardhat: {
        chainId: 31337,
        forking: {
            url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
            enabled: process.env.MAINNET_FORKING_ENABLED === "true",
            blockNumber: 9675000,
        },
        accounts: [
            {
                privateKey: deployerPK,
                balance: "10000000000000000000000",
            },
            {
                privateKey: deployerPK,
                balance: "10000000000000000000000",
            },
        ],
        // mock CLF data
        functionsDonId: process.env.CLF_DONID_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
        ccipBnmToken: process.env.CCIPBNM_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
    },
    // TESTNETS
    sepolia: {
        chainId: 11155111,
        url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [deployerPK],
        functionsDonId: process.env.CLF_DONID_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
        ccipBnmToken: process.env.CCIPBNM_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
        viemChain: chains_1.sepolia,
        name: "sepolia",
    },
    avalancheFuji: {
        chainId: 43113,
        url: `https://avalanche-fuji.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [deployerPK],
        functionsDonId: process.env.CLF_DONID_FUJI,
        functionsDonIdAlias: process.env.CLF_DONID_FUJI_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_FUJI,
        functionsSubIds: [process.env.CLF_SUBID_FUJI],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_FUJI,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_FUJI,
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_FUJI,
        linkPriceFeed: process.env.LINK_PRICEFEED_FUJI,
        ccipBnmToken: process.env.CCIPBNM_FUJI,
        ccipRouter: process.env.CL_CCIP_ROUTER_FUJI,
        viemChain: chains_1.avalancheFuji,
        name: "avalancheFuji",
    },
    optimismSepolia: {
        chainId: 11155420,
        url: `https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [deployerPK],
        functionsDonId: process.env.CLF_DONID_OPTIMISM_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_OPTIMISM_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_OPTIMISM_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_OPTIMISM_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_OPTIMISM_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA,
        conceroChainIndex: "2",
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_OPTIMISM_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_OPTIMISM_SEPOLIA,
        ccipBnmToken: process.env.CCIPBNM_OPTIMISM_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_OPTIMISM_SEPOLIA,
        viemChain: chains_1.optimismSepolia,
        name: "optimismSepolia",
        priceFeed: {
            linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_OPTIMISM_SEPOLIA,
            usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_OPTIMISM_SEPOLIA,
            nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_OPTIMISM_SEPOLIA,
            linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_OPTIMISM_SEPOLIA,
        },
    },
    arbitrumSepolia: {
        chainId: 421614,
        url: `https://arbitrum-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
        accounts: [deployerPK],
        functionsDonId: process.env.CLF_DONID_ARBITRUM_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_ARBITRUM_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_ARBITRUM_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_ARBITRUM_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_ARBITRUM_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA,
        conceroChainIndex: "0",
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_ARBITRUM_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_ARBITRUM_SEPOLIA,
        ccipBnmToken: process.env.CCIPBNM_ARBITRUM_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_ARBITRUM_SEPOLIA,
        viemChain: chains_1.arbitrumSepolia,
        name: "arbitrumSepolia",
        priceFeed: {
            linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_ARBITRUM_SEPOLIA,
            usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_ARBITRUM_SEPOLIA,
            nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_ARBITRUM_SEPOLIA,
            linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_ARBITRUM_SEPOLIA,
        },
    },
    baseSepolia: {
        chainId: 84532,
        url: `https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
        accounts: [deployerPK],
        functionsDonId: process.env.CLF_DONID_BASE_SEPOLIA,
        functionsDonIdAlias: process.env.CLF_DONID_BASE_SEPOLIA_ALIAS,
        functionsRouter: process.env.CLF_ROUTER_BASE_SEPOLIA,
        functionsSubIds: [process.env.CLF_SUBID_BASE_SEPOLIA],
        functionsGatewayUrls: exports.functionsGatewayUrls.testnet,
        donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_BASE_SEPOLIA,
        chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA,
        conceroChainIndex: "1",
        confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
        linkToken: process.env.LINK_BASE_SEPOLIA,
        linkPriceFeed: process.env.LINK_PRICEFEED_BASE_SEPOLIA,
        ccipBnmToken: process.env.CCIPBNM_BASE_SEPOLIA,
        ccipRouter: process.env.CL_CCIP_ROUTER_BASE_SEPOLIA,
        viemChain: chains_1.baseSepolia,
        name: "baseSepolia",
        priceFeed: {
            linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_BASE_SEPOLIA,
            usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_BASE_SEPOLIA,
            nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_BASE_SEPOLIA,
            linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_BASE_SEPOLIA,
        },
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
};
exports.default = CNetworks;