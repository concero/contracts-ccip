import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { task } from "hardhat/config";
import { upload } from "./upload";
import { getClients } from "../utils/switchChain";
import load from "../../utils/load";
import { liveChains } from "../concero/deployInfra";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import { CNetwork } from "../../types/CNetwork";
import { getEnvVar } from "../../utils/getEnvVar";

// run with: bunx clf-donsecrets-updatecontract --network avalancheFuji
task("clf-donsecrets-updatecontract", "Uploads DON secrets and updates contract variables")
  .addFlag("all", "List secrets from all chains")
  .setAction(async taskArgs => {
    if (taskArgs.all) await updateContract(liveChains);
    else await updateContract([chains[hre.network.name]]);
  });

export async function updateContract(chains: CNetwork[]) {
  const { abi } = await load("../artifacts/contracts/ConceroFunctions.sol/ConceroFunctions.json");
  for (const chain of chains) {
    const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, viemChain, url, name } = chain;
    const { signer } = getEthersSignerAndProvider(chain);

    if (!functionsGatewayUrls || functionsGatewayUrls.length === 0) throw Error(`No gatewayUrls found for ${name}.`);
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`); // grabbing up-to-date var

    const secretsManager = new SecretsManager({
      signer,
      functionsRouterAddress: functionsRouter,
      donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();

    const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
    const allSecrets = [];
    const res = result.nodeResponses[0];

    if (!res.rows) {
      console.log(`No secrets found for ${name}. Uploading secrets...`);
      const {
        slot_id: newSlotId,
        version: newVersion,
        expiration: newExpiration,
      } = await upload({ slotid: 0, ttl: 4320 });
      res.rows = [{ slot_id: newSlotId, version: newVersion, expiration: newExpiration }];
    }

    if (res.rows) {
      const row = res.rows.filter(row => row.slot_id === 0)[0];
      updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, row.version.toString(), "../../../.env.clf");
      updateEnvVariable(
        `CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[name]}`,
        row.expiration.toString(),
        "../../../.env.clf",
      );
      allSecrets.push(row);

      const { request: setDstConceroContractReq } = await publicClient.simulateContract({
        address: contract,
        abi,
        functionName: "setDonHostedSecretsVersion",
        account,
        args: [row.version],
        chain: viemChain,
      });

      const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
      const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setDstConceroContractHash,
      });
      console.log(
        `Set ${name}:${contract} setDonHostedSecretsVersion[${name}, ${row.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
      );
    }

    console.log(`DON secrets for ${name}:`);
    console.log(allSecrets);
  }
}

export default {};
