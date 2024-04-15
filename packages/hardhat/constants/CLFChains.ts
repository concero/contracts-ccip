import rpc from "./rpcUrls";

type envString = string | undefined;

export type ICLFChains = Record<
  string,
  {
    donId: envString;
    router: envString;
    chainSelector: envString;
    subscriptionId: envString;
    donHostedSecretsVersion: number;
    rpcUrl: string;
  }
>;

const CLFChains: ICLFChains = {
  sepolia: {
    donId: process.env.CLF_DONID_SEPOLIA,
    router: process.env.CLF_ROUTER_SEPOLIA,
    chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
    subscriptionId: process.env.CLF_SUBID_SEPOLIA,
    donHostedSecretsVersion: 1712841282,
    rpcUrl: rpc.sepolia,
  },
  avalancheFuji: {
    donId: process.env.CLF_DONID_FUJI,
    router: process.env.CLF_ROUTER_FUJI,
    chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_FUJI,
    subscriptionId: process.env.CLF_SUBID_FUJI,
    donHostedSecretsVersion: 1712841282,
    rpcUrl: rpc.avalancheFuji,
  },
  optimismSepolia: {
    donId: process.env.CLF_DONID_OPTIMISM_SEPOLIA,
    router: process.env.CLF_ROUTER_OPTIMISM_SEPOLIA,
    chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA,
    subscriptionId: process.env.CLF_SUBID_OPTIMISM_SEPOLIA,
    donHostedSecretsVersion: 1712841282,
    rpcUrl: rpc.optimismSepolia,
  },
  arbitrumSepolia: {
    donId: process.env.CLF_DONID_ARBITRUM_SEPOLIA,
    router: process.env.CLF_ROUTER_ARBITRUM_SEPOLIA,
    chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA,
    subscriptionId: process.env.CLF_SUBID_ARBITRUM_SEPOLIA,
    donHostedSecretsVersion: 1712841282,
    rpcUrl: rpc.arbitrumSepolia,
  },
  baseSepolia: {
    donId: process.env.CLF_DONID_BASE_SEPOLIA,
    router: process.env.CLF_ROUTER_BASE_SEPOLIA,
    chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA,
    subscriptionId: process.env.CLF_SUBID_BASE_SEPOLIA,
    donHostedSecretsVersion: 1712841282,
    rpcUrl: rpc.baseSepolia,
  },
};

export default CLFChains;
