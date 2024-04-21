import { SecretsManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { networkEnvKeys } from "../../constants/CNetworks";
import { task } from "hardhat/config";

import { uploadSecretsToDon } from "./uploadSecretsToDon";
// run with: bunx hardhat functions-list-don-secrets --network avalancheFuji
task("functions-ensure-don-secrets", "Displays encrypted secrets hosted on the DON").setAction(async taskArgs => {
  const { name } = hre.network;
  const signer = await hre.ethers.getSigner();
  const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls } = chains[name];

  if (!functionsGatewayUrls || functionsGatewayUrls.length === 0) {
    throw Error(`No gatewayUrls found for ${name}.`);
  }

  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress: functionsRouter,
    donId: functionsDonIdAlias,
  });
  await secretsManager.initialize();

  const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
  const allSecrets = [];
  for (const res of result.nodeResponses) {
    if (res.rows) {
      res.rows.forEach(row => {
        updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, row.version, "../../../.env.clf");
        updateEnvVariable(`CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[name]}`, row.expiration, "../../../.env.clf");
        allSecrets.push(row);
      });
    } else {
      console.log(`No secrets found for ${name}. Uploading secrets...`);
      await uploadSecretsToDon({ slotid: 0, ttl: 4320 });
    }
  }
  console.log(`DON secrets for ${name}:`);
  console.log(allSecrets);
});
export default {};
