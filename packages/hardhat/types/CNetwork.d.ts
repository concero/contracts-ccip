// Purpose: To have a single source of truth for networks across the project
import { NetworkUserConfig } from "hardhat/types";
import { HttpNetworkUserConfig } from "hardhat/src/types/config";
import { Chain } from "viem";

export type envString = string | undefined;
export type networks = "mainnet" | "arbitrum" | "optimism" | "polygon" | "polygonZkEvm" | "avalanche" | "base" | "sepolia" | "optimismSepolia" | "arbitrumSepolia" | "avalancheFuji" | "baseSepolia";
// Chainlink Functions Network specific configuration
export type CLFNetwork = {
  functionsRouter: envString;
  functionsDonId: envString;
  functionsDonIdAlias: envString;
  functionsSubIds: envString[];
  functionsGatewayUrls: string[];
  gatewayUrls: string[];
  confirmations: number;
  chainSelector: envString;
  conceroChainIndex: number;
  donHostedSecretsVersion: envString;
  linkToken: envString;
  linkPriceFeed: envString;
  viemChain: Chain;
};

// Chainlink CCIP Network specific configuration
export type CLCCIPNetwork = {
  linkToken: envString;
  ccipRouter: envString;
  chainSelector: envString;
};

// Combined network configuration type
export type CNetwork = NetworkUserConfig & HttpNetworkUserConfig & Partial<CLFNetwork> & Partial<CLCCIPNetwork>;
