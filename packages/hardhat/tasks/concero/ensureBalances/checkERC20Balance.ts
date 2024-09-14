import type { CNetwork } from "../../../types/CNetwork";
import { getFallbackClients } from "../../../utils/getViemClients";
import { erc20Abi } from "viem";

async function checkERC20Balance(chain: CNetwork, token: string, address: string): Promise<bigint> {
  const { publicClient } = getFallbackClients(chain);
  return await publicClient.readContract({
    address: token,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address]
  });
}

export default checkERC20Balance;
