import { type EnvCLCCIP } from "./env.clccip";
import { type EnvCLA } from "./env.cla";
import { type EnvCLF } from "./env.clf";
import { EnvTokens } from "./env.tokens";

export interface env extends EnvCLA, EnvCLF, EnvCLCCIP, EnvTokens {
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
}

export default env;
