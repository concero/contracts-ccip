import type { CNetwork } from "../../../types/CNetwork";
import { getFallbackClients } from "../../../utils";
import { erc20Abi } from "viem";
import { BalanceInfo } from "./types";

async function checkERC20Balance(chain: CNetwork, token: string, address: string): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);
  const [balance, symbol, decimals] = await Promise.all([
    publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [address],
    }),
    publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "symbol",
    }),
    publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "decimals",
    }),
  ]);

  const donorBalance = await publicClient.readContract({
    address: token,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [process.env.DEPLOYER_ADDRESS],
  });

  return {
    chain,
    balance,
    symbol,
    decimals,
    deficit: BigInt(0), // This will be calculated in the calling function
    donorBalance,
    type: "ERC20",
    address,
  };
}

export default checkERC20Balance;
