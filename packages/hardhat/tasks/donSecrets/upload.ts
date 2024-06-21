import { task, types } from "hardhat/config";
import { SecretsManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import secrets from "../../constants/CLFSecrets";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { CNetwork } from "../../types/CNetwork";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import log from "../../utils/log";
import listSecrets from "./list";
import { setDonHostedSecretsVersion } from "../concero/setContractVariables";
import load from "../../utils/load";
import { liveChains } from "../concero/deployInfra";

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

    console.log("Uploading secrets to DON for network:", name);
    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

    const {
      version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
      success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
    } = await secretsManager.uploadEncryptedSecretsToDON({
      encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
      gatewayUrls: ["https://01.functions-gateway.chain.link/", "https://02.functions-gateway.chain.link/"],
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
  .addFlag("all", "Upload secrets to all networks")
  .addFlag("updatecontracts", "Update the contracts with the new secrets")
  // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
  .setAction(async taskArgs => {
    const hre = require("hardhat");
    const { slotid, ttl, all, updatecontracts } = taskArgs;

    // Function to upload secrets and optionally update contracts
    const processNetwork = async (chain: CNetwork) => {
      await upload([chain], slotid, ttl);
      if (updatecontracts) {
        const { abi } = await load("../artifacts/contracts/Concero.sol/Concero.json");
        await setDonHostedSecretsVersion(chain, parseInt(slotid), abi);
      }
    };

    // Process all networks if 'all' flag is set
    if (all) {
      for (const liveChain of liveChains) {
        await processNetwork(liveChain);
      }
    } else {
      await processNetwork(chains[hre.network.name]);
    }
  });

export default upload;
