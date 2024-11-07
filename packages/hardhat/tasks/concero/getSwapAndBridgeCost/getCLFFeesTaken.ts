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

  const srcClfFee = await publicClient.readContract({
    address: infraProxyAddress,
    abi: clfFeeAbi,
    functionName: "clfPremiumFees",
    args: [srcChainSelector],
    blockNumber,
  });

  const dstClfFee = await publicClient.readContract({
    address: infraProxyAddress,
    abi: clfFeeAbi,
    functionName: "clfPremiumFees",
    args: [dstChainSelector],
    blockNumber,
  });

  const srcMessengerGasFee = await publicClient.readContract({
    address: infraProxyAddress,
    abi: gasFeeAbi,
    functionName: "s_lastGasPrices",
    args: [srcChainSelector],
    blockNumber,
  });

  const dstMessengerGasFee = await publicClient.readContract({
    address: infraProxyAddress,
    abi: gasFeeAbi,
    functionName: "s_lastGasPrices",
    args: [dstChainSelector],
    blockNumber,
  });

  return {
    srcClfFee,
    dstClfFee,
    srcMessengerGasFee,
    dstMessengerGasFee,
  };
}
