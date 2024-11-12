import { PublicClient } from "viem/clients/createPublicClient";
import { Address, parseAbi } from "viem";

export async function getCLFFeesTaken(
  publicClient: PublicClient,
  infraProxyAddress: Address,
  srcChainSelector: bigint | string,
  dstChainSelector: bigint | string,
  blockNumber: bigint,
) {
  const clfFeeAbi = parseAbi(["function clfPremiumFees(uint64) external view returns(uint256)"]);
  const gasFeeAbi = parseAbi(["function s_lastGasPrices(uint64) external view returns(uint256)"]);
  const ccipFeeAbi = parseAbi(["function s_latestLinkUsdcRate() external view returns(uint256)"]);

  const [srcClfFeeTaken, dstClfFeeTaken, srcMessengerGasFeeTaken, dstMessengerGasFeeTaken, latestLinkUsdcRate] =
    await Promise.all([
      publicClient.readContract({
        address: infraProxyAddress,
        abi: clfFeeAbi,
        functionName: "clfPremiumFees",
        args: [srcChainSelector],
        blockNumber,
      }),
      publicClient.readContract({
        address: infraProxyAddress,
        abi: clfFeeAbi,
        functionName: "clfPremiumFees",
        args: [dstChainSelector],
        blockNumber,
      }),
      publicClient.readContract({
        address: infraProxyAddress,
        abi: gasFeeAbi,
        functionName: "s_lastGasPrices",
        args: [srcChainSelector],
        blockNumber,
      }),
      publicClient.readContract({
        address: infraProxyAddress,
        abi: gasFeeAbi,
        functionName: "s_lastGasPrices",
        args: [dstChainSelector],
        blockNumber,
      }),
      publicClient.readContract({
        address: infraProxyAddress,
        abi: ccipFeeAbi,
        functionName: "s_latestLinkUsdcRate",
        args: [],
        blockNumber,
      }),
    ]);

  return {
    srcClfFeeTaken,
    dstClfFeeTaken,
    srcMessengerGasFeeTaken,
    dstMessengerGasFeeTaken,
    latestLinkUsdcRate,
  };
}
