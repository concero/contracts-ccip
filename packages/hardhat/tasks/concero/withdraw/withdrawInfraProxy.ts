import { task } from "hardhat/config";
import chains, { networkEnvKeys } from "../../../constants/CNetworks";
import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/getViemClients";
import { getEnvVar } from "../../../utils/getEnvVar";
import { Address, erc20Abi } from "viem";
import log from "../../../utils/log";
import load from "../../../utils/load";

const getBalance = async (tokenAddress: Address, account: Address, chain: CNetwork) => {
  const { publicClient } = getClients(chain.viemChain, chain.url);

  return await publicClient.readContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [account],
  });
};

const withdrawToken = async (chain: CNetwork, tokenAddress) => {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = chain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  const conceroProxy = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dcName]}`);
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  try {
    const usdBalance = await getBalance(tokenAddress, conceroProxy, chain);
    console.log(usdBalance);

    if (usdBalance < 1n) {
      log(`Not enough balance to withdraw for ${dcName}`, "withdrawToken");
      return;
    }

    const { request: withdrawReq } = await publicClient.simulateContract({
      address: conceroProxy as Address,
      abi,
      functionName: "withdraw",
      account,
      args: [account.address, tokenAddress, usdBalance],
      chain: dcViemChain,
    });
    const hash = await walletClient.writeContract(withdrawReq);
    const { cumulativeGasUsed: setDonSecretsSlotIdGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
    log(
      `Set ${dcName}:${conceroProxy} amount to withdraw: ${usdBalance}. Gas used: ${setDonSecretsSlotIdGasUsed.toString()}`,
      "withdrawToken",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setDonHostedSecretsSlotID");
  }
};

// todo: can be withdraw with --infra-proxy flag to be applied to multiple contracts
task("withdraw-infra-proxy", "Withdraws the token from the proxy contract")
  .addParam("tokenaddress", "Token Address")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    if (name !== "localhost" && name !== "hardhat") {
      await withdrawToken(chains[name], taskArgs.tokenaddress);
    }
  });

export default {};
