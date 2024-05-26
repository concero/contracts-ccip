import { task, types } from "hardhat/config";
import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import secrets from "../../constants/CLFSecrets";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../types/CNetwork";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import log from "../../utils/log";
import listSecrets from "./list";

// const path = require("path");

async function upload(chains: CNetwork[], slotid: number, ttl: number) {
  const slotId = parseInt(slotid);
  const minutesUntilExpiration = ttl;

  for (const chain of chains) {
    const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, url, name } = chain;
    const { signer } = await getEthersSignerAndProvider(url);

    const secretsManager = new SecretsManager({
      signer,
      functionsRouterAddress: functionsRouter,
      donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();

    // Dynamically import the config file if necessary
    // const configPath = path.isAbsolute(taskArgs.configpath) ? taskArgs.configpath : path.join(process.cwd(), taskArgs.configpath);
    // const requestConfig = await import(configPath);

    if (!secrets) {
      console.error("No secrets to upload.");
      return;
    }
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

    log(
      `DONSecrets uploaded to ${name}. slot_id: ${slotId}, version: ${version}, ttl: ${minutesUntilExpiration}`,
      "donSecrets/upload",
    );

    await listSecrets(chain);

    // log(`Current DONSecrets for ${name}:`, "donSecrets/upload");
    // log(checkSecretsRes, "donSecrets/upload");

    updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, version, "../../../.env.clf");
  }
}

// run with: yarn hardhat clf-donsecrets-upload --slotid 0 --ttl 4320 --network avalancheFuji
// todo: add to deployedSecrets file with expiration time, and check if it's expired before using itV
task("clf-donsecrets-upload", "Encrypts and uploads secrets to the DON")
  .addParam(
    "slotid",
    "Storage slot number 0 or higher - if the slotid is already in use, the existing secrets for that slotid will be overwritten",
  )
  .addOptionalParam("ttl", "Time to live - minutes until the secrets hosted on the DON expire", 4320, types.int)
  // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");

    const { slotid, ttl } = taskArgs;
    await upload([chains[hre.network.name]], slotid, ttl);
  });

export default upload;
