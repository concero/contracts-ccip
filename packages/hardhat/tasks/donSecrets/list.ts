import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { liveChains } from "../concero/deployInfra";
import { CNetwork } from "../../types/CNetwork";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import log from "../../utils/log";

async function listSecrets(chain: CNetwork): Promise<{ [slotId: number]: { version: number; expiration: number } }> {
  const { provider, signer } = getEthersSignerAndProvider(chain.url);
  const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls } = chain;
  if (!functionsGatewayUrls || functionsGatewayUrls.length === 0)
    throw Error(`No gatewayUrls found for ${chain.name}.`);

  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress: functionsRouter,
    donId: functionsDonIdAlias,
  });
  await secretsManager.initialize();

  const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
  const allSecrets = {};

  result.nodeResponses.forEach(nodeResponse => {
    if (nodeResponse.rows) {
      nodeResponse.rows.forEach(row => {
        if (allSecrets[row.slot_id] && allSecrets[row.slot_id].version !== row.version)
          return log(`Node mismatch for slot_id. ${allSecrets[row.slot_id]} !== ${row.slot_id}!`, "listSecrets");
        allSecrets[row.slot_id] = { version: row.version, expiration: row.expiration };
      });
    }
    // else {
    //   // updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[chain.name]}`, "0", "../../../.env.clf");
    // }
  });
  log(`DON secrets for ${chain.name}:`, "listSecrets");
  console.log(allSecrets);
  return allSecrets;
}

// run with: yarn hardhat clf-donsecrets-list --network avalancheFuji
task("clf-donsecrets-list", "Displays encrypted secrets hosted on the DON")
  .addFlag("all", "List secrets from all chains")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { all } = taskArgs;
    if (all) {
      for (const chain of liveChains) {
        console.log(`\nListing secrets for ${chain.name}`);
        await listSecrets(chain);
      }
    } else {
      const { name } = hre.network;
      await listSecrets(chains[name]);
    }
  });

export default listSecrets;
