import { SecretsManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { networkEnvKeys } from "../../constants/CNetworks";
import { task } from "hardhat/config";

// run with: bunx hardhat functions-list-don-secrets --network avalancheFuji
task("functions-list-don-secrets", "Displays encrypted secrets hosted on the DON").setAction(async taskArgs => {
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
  // console.log(`\nYour encrypted secrets currently hosted on DON ${functionsDonIdAlias}`);
  let i = 0;
  result.nodeResponses.forEach(nodeResponse => {
    // console.log(`\nNode Response #${i}`);
    i++;

    if (nodeResponse.rows) {
      nodeResponse.rows.forEach(row => {
        if (row.version && row.expiration) {
          updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, row.version, "../../../.env.clf");
          updateEnvVariable(`CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[name]}`, row.expiration, "../../../.env.clf");
        }
        // console.log(row);
        allSecrets.push(row);
      });
    } else {
      updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, "0", "../../../.env.clf");
    }
  });
  console.log(`DON secrets for ${name}:`);
  console.log(JSON.stringify(allSecrets));
  return JSON.stringify(allSecrets);
});
export default {};
