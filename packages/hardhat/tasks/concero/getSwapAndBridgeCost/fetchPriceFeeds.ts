import priceFeedAbi from "@chainlink/contracts/abi/v0.8/AggregatorV2V3Interface.json";
import { PublicClient } from "viem/clients/createPublicClient";
import { CNetwork } from "../../../types/CNetwork";
import { getEnvVar } from "../../../utils";
import { networkEnvKeys } from "../../../constants";

export async function fetchPriceFeeds(chain: CNetwork, publicClient: PublicClient, blockNumber?: bigint) {
  const priceFeeds = {
    LINKUSD: getEnvVar(`LINK_USD_PRICEFEED_${networkEnvKeys[chain.name]}`),
    USDCUSD: getEnvVar(`USDC_USD_PRICEFEED_${networkEnvKeys[chain.name]}`),
  };

  const [LINKUSDPrice, USDCUSDPrice] = await Promise.all([
    publicClient.readContract({
      address: priceFeeds.LINKUSD,
      abi: priceFeedAbi,
      functionName: "latestAnswer",
      args: [],
      ...(blockNumber && { blockNumber }),
    }),
    publicClient.readContract({
      address: priceFeeds.USDCUSD,
      abi: priceFeedAbi,
      functionName: "latestAnswer",
      args: [],
      ...(blockNumber && { blockNumber }),
    }),
  ]);

  return {
    LINKUSDPrice,
    USDCUSDPrice,
  };
}
