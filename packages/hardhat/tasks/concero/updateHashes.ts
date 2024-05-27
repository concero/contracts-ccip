import { task } from "hardhat/config";
import { liveChains } from "./deployInfra";
import { CNetwork } from "../../types/CNetwork";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import { getEnvVar } from "../../utils/getEnvVar";
import { getClients } from "../utils/switchChain";
import load from "../../utils/load";
import getHashSum from "../../utils/getHashSum";
import secrets from "../../constants/CLFSecrets";
import log from "../../utils/log";

async function updateHashes(chain: CNetwork) {
  const { name, url, viemChain } = chain;
  const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);
  const { walletClient, publicClient, account } = getClients(viemChain, url);
  const { abi } = await load("../artifacts/contracts/Concero.sol/Concero.json");
  // todo: make public variables for this to work
  // const result = await publicClient.readContract({
  //   address: contract,
  //   abi,
  //   functionName: "JsCodeHashSum",
  //   account,
  //   chain: viemChain,
  // });
  //
  // if (result.status === "success") {
  //   console.log(`Read Hash of the contract on ${name}: ${result.result}`);
  // }

  const srcHash = getHashSum(secrets.SRC_JS);
  const dstHash = getHashSum(secrets.DST_JS);

  const { request: updateHashReq } = await publicClient.simulateContract({
    address: contract,
    abi,
    functionName: "setSrcJsHashSum",
    account,
    chain: viemChain,
    args: [srcHash],
  });

  const updateHashRes = await walletClient.writeContract(updateHashReq);
  const { cumulativeGasUsed: updateHashGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: updateHashRes,
  });

  log(`Set ${name}:${contract} setSrcJsHashSum[${srcHash}] Gas used: ${updateHashGasUsed.toString()}`, "update-hashes");

  const { request: updateDstHashReq } = await publicClient.simulateContract({
    address: contract,
    abi,
    functionName: "setDstJsHashSum",
    account,
    chain: viemChain,
    args: [dstHash],
  });

  const updateDstHashRes = await walletClient.writeContract(updateDstHashReq);
  const { cumulativeGasUsed: updateDstHashGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: updateDstHashRes,
  });

  log(
    `Set ${name}:${contract} setDstJsHashSum[${dstHash}] Gas used: ${updateDstHashGasUsed.toString()}`,
    "update-hashes",
  );
}

task("update-hashes", "Update the hashes of the contracts")
  .addFlag("all", "Update all contracts")
  .setAction(async (taskArgs, hre) => {
    if (taskArgs.all) {
      for (const liveChain of liveChains) {
        await updateHashes(liveChain);
      }
    }
    const { name } = hre.network;

    await updateHashes(chains[name]);
  });

export default {};
