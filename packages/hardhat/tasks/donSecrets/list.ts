import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { liveChains } from "../concero/deployInfra";
import { CNetwork } from "../../types/CNetwork";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";

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

async function listSecrets(chain: CNetwork) {
  const { provider, signer } = getEthersSignerAndProvider(chain);

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
  const allSecrets = [];
  let i = 0;
  result.nodeResponses.forEach(nodeResponse => {
    i++;

    if (nodeResponse.rows) {
      nodeResponse.rows.forEach(row => {
        if (row.version && row.expiration) {
          updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[chain.name]}`, row.version, "../../../.env.clf");
          updateEnvVariable(
            `CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[chain.name]}`,
            row.expiration,
            "../../../.env.clf",
          );
        }
        allSecrets.push(row);
      });
    } else {
      updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[chain.name]}`, "0", "../../../.env.clf");
    }
  });
  console.log(`DON secrets for ${chain.name}:`);
  console.log(JSON.stringify(allSecrets));
  return JSON.stringify(allSecrets);
}

export default {};
