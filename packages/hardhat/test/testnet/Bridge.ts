import "@nomicfoundation/hardhat-chai-matchers";
import { parseUnits } from "viem";
import { bridgeBase } from "../testBase/bridgeBase";
import { getFallbackClients } from "../../utils";
import { cNetworks } from "../../constants";

describe("bridge", () => {
  const { walletClient, publicClient } = getFallbackClients(cNetworks.arbitrumSepolia);
  const senderAddress = process.env.DEPLOYER_ADDRESS;
  const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
  const srcTokenAddress = process.env.USDC_ARBITRUM_SEPOLIA;
  const srcTokenAmount = parseUnits("1", 6);
  const srcContractAddress = process.env.CONCERO_INFRA_PROXY_ARBITRUM_SEPOLIA;

  it("should bridge", () =>
    bridgeBase({
      srcTokenAddress,
      srcTokenAmount,
      srcContractAddress,
      dstChainSelector,
      senderAddress,
      walletClient,
      publicClient,
    })).timeout(0);
});
