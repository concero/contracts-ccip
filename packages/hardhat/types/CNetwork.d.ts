import CNetworks from "../constants/CNetworks";
import { HardhatNetworkUserConfig, NetworkUserConfig } from "hardhat/types";
import { HttpNetworkUserConfig } from "hardhat/src/types/config";
// import {} from "hardhat/src/types/config";
// Chainlink Functions Network specific configuration
export type envString = string | undefined;

export type CLFNetwork = {
  functionsRouter: envString;
  functionsDonId: envString;
  functionsDonIdAlias: envString;
  functionsSubIds: envString[];
  gatewayUrls: string[];
  confirmations: number;
  chainSelector: envString;
  donHostedSecretsVersion: number;
  linkToken: envString;
  linkPriceFeed: envString;
};

// Chainlink CCIP Network specific configuration
export type CLCCIPNetwork = {
  linkToken: envString;
  ccipRouter: envString;
  chainSelector: envString;
};

// Combined network configuration type
export type CNetwork = NetworkUserConfig & Partial<CLFNetwork> & Partial<CLCCIPNetwork>;
