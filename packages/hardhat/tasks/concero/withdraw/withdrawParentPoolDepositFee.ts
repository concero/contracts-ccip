import { task } from "hardhat/config";
import chains from "../../../constants/CNetworks";
import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/getViemClients";
import { getEnvVar } from "../../../utils/getEnvVar";
import { Address } from "viem";
import log from "../../../utils/log";
import load from "../../../utils/load";

const withdrawToken = async (chain: CNetwork) => {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = chain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  const conceroProxy = getEnvVar(`PARENT_POOL_PROXY_BASE`);
  const { abi } = await load("../artifacts/contracts/ConceroParentPool.sol/ConceroParentPool.json");

  try {
    const { request: withdrawReq } = await publicClient.simulateContract({
      address: conceroProxy as Address,
      abi,
      functionName: "withdrawDepositFees",
      account,
      args: [],
      chain: dcViemChain,
    });
    const hash = await walletClient.writeContract(withdrawReq);
    const { cumulativeGasUsed: setDonSecretsSlotIdGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
    log(
      `Withdrawn from ${dcName}:${conceroProxy}. Gas used: ${setDonSecretsSlotIdGasUsed.toString()}`,
      "withdrawToken",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "withdrawDepositFees");
  }
};

// todo: can be withdraw with --infra-proxy flag to be applied to multiple contracts
task("withdraw-parent-pool-fee", "Withdraws the token from the proxy contract").setAction(async taskArgs => {
  const { name, live } = hre.network;

  if (live) {
    await withdrawToken(chains[name]);
  }
});

export default {};
