import { parseUnits } from "viem";
import { bridgeBase } from "../testBase/bridgeBase";
import { getFallbackClients } from "../../../utils/";
import { conceroNetworks } from "../../../constants";

describe("bridge", () => {
  const { walletClient, publicClient } = getFallbackClients(conceroNetworks.baseSepolia);
  const senderAddress = process.env.DEPLOYER_ADDRESS;
  const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA;
  const srcTokenAddress = process.env.USDC_BASE_SEPOLIA;
  const srcTokenAmount = parseUnits("1", 6);
  const srcContractAddress = process.env.CONCERO_INFRA_PROXY_BASE_SEPOLIA;

  it("should bridge", async () => {
    try {
      await bridgeBase({
        srcTokenAddress,
        srcTokenAmount,
        srcContractAddress,
        dstChainSelector,
        senderAddress,
        walletClient,
        publicClient,
      });
    } catch (error) {
      console.error("Bridge test failed:", error);
      throw error;
    }
  });
});
