import { task, types } from "hardhat/config";
import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import secrets from "../../constants/CLFSecrets";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { HardhatRuntimeEnvironment } from "hardhat/types";
// const path = require("path");
// run with: bunx hardhat functions-upload-secrets-don --slotid 0 --ttl 4320 --network avalancheFuji

// todo: add to deployedSecrets file with expiration time, and check if it's expired before using itV
task("clf-donsecrets-upload", "Encrypts and uploads secrets to the DON")
  .addParam(
    "slotid",
    "Storage slot number 0 or higher - if the slotid is already in use, the existing secrets for that slotid will be overwritten",
  )
  .addOptionalParam(
    "ttl",
    "Time to live - minutes until the secrets hosted on the DON expire (defaults to 10, and must be at least 5)",
    10,
    types.int,
  )
  // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
  .setAction(async taskArgs => {
    await upload(taskArgs);
  });
export default {};

export async function upload(taskArgs) {
  const hre: HardhatRuntimeEnvironment = require("hardhat");

  const { name } = hre.network;
  const signer = await hre.ethers.getSigner();
  const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls } = chains[name];

  const slotId = parseInt(taskArgs.slotid);
  const minutesUntilExpiration = taskArgs.ttl;

  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress: functionsRouter,
    donId: functionsDonIdAlias,
  });
  await secretsManager.initialize();

  // Dynamically import the config file if necessary
  // const configPath = path.isAbsolute(taskArgs.configpath) ? taskArgs.configpath : path.join(process.cwd(), taskArgs.configpath);
  // const requestConfig = await import(configPath);

  if (!secrets) return console.error("No secrets found.");
  // console.log("Uploading secrets to DON for network:", name);
  const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

  const {
    version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
    success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
  } = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
    gatewayUrls: functionsGatewayUrls,
    slotId,
    minutesUntilExpiration,
  });

  console.log(`Secrets uploaded to DON for network: ${name} with version: ${version}`);
  updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, version, "../../../.env.clf");
}
