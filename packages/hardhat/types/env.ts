export interface env {
  //.env
  PROXY_DEPLOYER_ADDRESS: string;
  PROXY_DEPLOYER_PRIVATE_KEY: string;
  DEPLOYER_ADDRESS: string;
  DEPLOYER_PRIVATE_KEY: string;
  MESSENGER_PRIVATE_KEY: string;
  MAINNET_FORKING_ENABLED: string;
  INFURA_API_KEY: string;
  ALCHEMY_API_KEY: string;
  ETHERSCAN_API_KEY: string;
  CHAINSTACK_API_KEY: string;
  CONCERO_BRIDGE_SEPOLIA: string;
  CONCERO_BRIDGE_ARBITRUM_SEPOLIA: string;
  CONCERO_BRIDGE_BASE_SEPOLIA: string;
  CONCERO_BRIDGE_FUJI: string;
  CONCERO_BRIDGE_OPTIMISM_SEPOLIA: string;
  MESSENGER_0_ADDRESS: string;
  MESSENGER_1_ADDRESS: string;
  MESSENGER_2_ADDRESS: string;
  POOL_MESSENGER_0_ADDRESS: string;
  POOL_MESSENGER_0_PRIVATE_KEY: string;
  MESSENGER_0_PRIVATE_KEY: string;
  MESSENGER_1_PRIVATE_KEY: string;
  MESSENGER_2_PRIVATE_KEY: string;
  // .env.clf
  CLF_SUBID_SEPOLIA: string;
  CLF_SUBID_ARBITRUM_SEPOLIA: string;
  CLF_SUBID_OPTIMISM_SEPOLIA: string;
  CLF_SUBID_FUJI: string;
  CLF_SUBID_BASE_SEPOLIA: string;
  CLF_DON_SECRETS_VERSION_SEPOLIA: string;
  CLF_DON_SECRETS_VERSION_ARBITRUM_SEPOLIA: string;
  CLF_DON_SECRETS_VERSION_OPTIMISM_SEPOLIA: string;
  CLF_DON_SECRETS_VERSION_FUJI: string;
  CLF_DON_SECRETS_VERSION_BASE_SEPOLIA: string;
  CLF_DON_SECRETS_VERSION_MAINNET: string;
  CLF_DON_SECRETS_VERSION_ARBITRUM: string;
  CLF_DON_SECRETS_VERSION_POLYGON: string;
  CLF_DON_SECRETS_VERSION_AVALANCHE: string;
  CLF_DON_SECRETS_VERSION_BASE: string;

  CLF_DON_SECRETS_EXPIRATION_SEPOLIA: string;
  CLF_DON_SECRETS_EXPIRATION_ARBITRUM_SEPOLIA: string;
  CLF_DON_SECRETS_EXPIRATION_OPTIMISM_SEPOLIA: string;
  CLF_DON_SECRETS_EXPIRATION_FUJI: string;
  CLF_DON_SECRETS_EXPIRATION_BASE_SEPOLIA: string;
  CLF_DON_SECRETS_EXPIRATION_MAINNET: string;
  CLF_DON_SECRETS_EXPIRATION_ARBITRUM: string;
  CLF_DON_SECRETS_EXPIRATION_POLYGON: string;
  CLF_DON_SECRETS_EXPIRATION_AVALANCHE: string;
  CLF_DON_SECRETS_EXPIRATION_BASE: string;

  CLF_ROUTER_MAINNET: string;
  CLF_ROUTER_ARBITRUM: string;
  CLF_ROUTER_POLYGON: string;
  CLF_ROUTER_AVALANCHE: string;
  CLF_ROUTER_BASE: string;
  CLF_ROUTER_SEPOLIA: string;
  CLF_ROUTER_ARBITRUM_SEPOLIA: string;
  CLF_ROUTER_FUJI: string;
  CLF_ROUTER_BASE_SEPOLIA: string;
  CLF_ROUTER_OPTIMISM_SEPOLIA: string;
  CLF_DONID_MAINNET: string;
  CLF_DONID_ARBITRUM: string;
  CLF_DONID_POLYGON: string;
  CLF_DONID_AVALANCHE: string;
  CLF_DONID_BASE: string;
  CLF_DONID_MAINNET_ALIAS: string;
  CLF_DONID_ARBITRUM_ALIAS: string;
  CLF_DONID_POLYGON_ALIAS: string;
  CLF_DONID_AVALANCHE_ALIAS: string;
  CLF_DONID_BASE_ALIAS: string;
  CLF_DONID_SEPOLIA: string;
  CLF_DONID_ARBITRUM_SEPOLIA: string;
  CLF_DONID_FUJI: string;
  CLF_DONID_BASE_SEPOLIA: string;
  CLF_DONID_OPTIMISM_SEPOLIA: string;
  CLF_DONID_SEPOLIA_ALIAS: string;
  CLF_DONID_ARBITRUM_SEPOLIA_ALIAS: string;
  CLF_DONID_FUJI_ALIAS: string;
  CLF_DONID_BASE_SEPOLIA_ALIAS: string;
  CLF_DONID_OPTIMISM_SEPOLIA_ALIAS: string;
  // env.clccip
  CL_CCIP_ROUTER_MAINNET: string;
  CL_CCIP_ROUTER_OPTIMISM: string;
  CL_CCIP_ROUTER_ARBITRUM: string;
  CL_CCIP_ROUTER_POLYGON: string;
  CL_CCIP_ROUTER_AVALANCHE: string;
  CL_CCIP_ROUTER_BASE: string;
  CL_CCIP_ROUTER_BNB: string;
  CL_CCIP_ROUTER_SEPOLIA: string;
  CL_CCIP_ROUTER_ARBITRUM_SEPOLIA: string;
  CL_CCIP_ROUTER_FUJI: string;
  CL_CCIP_ROUTER_BASE_SEPOLIA: string;
  CL_CCIP_ROUTER_OPTIMISM_SEPOLIA: string;
  CL_CCIP_ROUTER_BNB_TESTNET: string;
  CL_CCIP_ROUTER_GNOSIS_CHIADO: string;
  CL_CCIP_CHAIN_SELECTOR_MAINNET: string;
  CL_CCIP_CHAIN_SELECTOR_OPTIMISM: string;
  CL_CCIP_CHAIN_SELECTOR_ARBITRUM: string;
  CL_CCIP_CHAIN_SELECTOR_POLYGON: string;
  CL_CCIP_CHAIN_SELECTOR_AVALANCHE: string;
  CL_CCIP_CHAIN_SELECTOR_BNB: string;
  CL_CCIP_CHAIN_SELECTOR_BASE: string;
  CL_CCIP_CHAIN_SELECTOR_SEPOLIA: string;
  CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA: string;
  CL_CCIP_CHAIN_SELECTOR_BNB_TESTNET: string;
  CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA: string;
  CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA: string;
  CL_CCIP_CHAIN_SELECTOR_GNOSIS_CHIADO: string;
  CL_CCIP_CHAIN_SELECTOR_FUJI: string;
  // env.tokens
  LINK_MAINNET: string;
  LINK_ARBITRUM: string;
  LINK_POLYGON: string;
  LINK_OPTIMISM: string;
  LINK_AVALANCHE: string;
  LINK_BNB: string;
  LINK_GNOSIS: string;
  LINK_FANTOM: string;
  LINK_BASE: string;
  LINK_SCROLL: string;
  LINK_LINEA: string;
  LINK_ZKSYNC: string;
  LINK_POLYGONZKEVM: string;
  LINK_SEPOLIA: string;
  LINK_ARBITRUM_SEPOLIA: string;
  LINK_OPTIMISM_SEPOLIA: string;
  LINK_BASE_SEPOLIA: string;
  LINK_SCROLL_SEPOLIA: string;
  LINK_ZKSYNC_SEPOLIA: string;
  LINK_POLYGONZKEVM_TESTNET: string;
  LINK_FUJI: string;
  LINK_BNB_TESTNET: string;
  LINK_GNOSIS_CHIADO: string;
  LINK_FANTOM_TESTNET: string;
  USDC_MAINNET: string;
  USDC_ARBITRUM: string;
  USDC_POLYGON: string;
  USDC_AVALANCHE: string;
  USDC_BASE: string;
  USDC_SEPOLIA: string;
  USDC_ARBITRUM_SEPOLIA: string;
  USDC_BASE_SEPOLIA: string;
  USDC_AMOY: string;
  USDC_FUJI: string;
  USDC_ZKSYNC_TESTNET: string;
  CCIPBNM_SEPOLIA: string;
  CCIPBNM_ARBITRUM_SEPOLIA: string;
  CCIPBNM_FUJI: string;
  CCIPBNM_BNB: string;
  CCIPBNM_BASE_SEPOLIA: string;
  CCIPBNM_OPTIMISM_SEPOLIA: string;
  CCIPBNM_GNOSIS_CHIADO: string;
  GHO_SEPOLIA: string;
  GHO_ARBITRUM_SEPOLIA: string;
  LINK_PRICEFEED_MAINNET: string;
  LINK_PRICEFEED_ARBITRUM: string;
  LINK_PRICEFEED_AVALANCHE: string;
  LINK_PRICEFEED_POLYGON: string;
  LINK_PRICEFEED_SEPOLIA: string;
  LINK_PRICEFEED_ARBITRUM_SEPOLIA: string;
  LINK_PRICEFEED_FUJI: string;
  LINK_PRICEFEED_BASE_SEPOLIA: string;
  LINK_PRICEFEED_OPTIMISM_SEPOLIA: string;
}

export default env;
