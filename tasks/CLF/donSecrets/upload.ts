import { task, types } from "hardhat/config";
import { SecretsManager } from "@chainlink/functions-toolkit";
import { networkEnvKeys } from "../../../constants/conceroNetworks";
import secrets from "../../../constants/CLFSecrets";
import updateEnvVariable from "../../../utils/updateEnvVariable";
import { CNetwork } from "../../../types/CNetwork";
import { getEthersSignerAndProvider } from "../../../utils";
import log, { err } from "../../../utils/log";
import listSecrets from "./list";
import { setDonHostedSecretsVersion } from "../../concero/deployInfra/setContractVariables";
import { liveChains } from "../../../constants";
import { HardhatRuntimeEnvironment } from "hardhat/types";

async function upload(chains: CNetwork[], slotid: number, ttl: number) {
  const slotId = parseInt(slotid);
  const minutesUntilExpiration = ttl;

  for (const chain of chains) {
    const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, name } = chain;
    const { signer } = getEthersSignerAndProvider(chain.url);

    const secretsManager = new SecretsManager({
      signer,
      functionsRouterAddress: functionsRouter,
      donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();

    if (!secrets) {
      err("No secrets to upload.", "donSecrets/upload", name);
      return;
    }

    log("Uploading secrets to DON", "donSecrets/upload", name);
    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

    const { version, success } = await secretsManager.uploadEncryptedSecretsToDON({
      encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
      gatewayUrls: functionsGatewayUrls,
      slotId,
      minutesUntilExpiration,
    });

    log(
      `DONSecrets uploaded. slot_id: ${slotId}, version: ${version}, ttl: ${minutesUntilExpiration}`,
      "donSecrets/upload",
      name,
    );

    await listSecrets(chain);

    updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, version, `clf`);
  }
}

task("clf-donsecrets-upload", "Encrypts and uploads secrets to the DON")
  .addParam(
    "slotid",
    "Storage slot number 0 or higher - if the slotid is already in use, the existing secrets for that slotid will be overwritten",
  )
  .addOptionalParam("ttl", "Time to live - minutes until the secrets hosted on the DON expire", 4320, types.int)
  .addFlag("all", "Upload secrets to all networks")
  .addFlag("updatecontracts", "Update the contracts with the new secrets")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { slotid, ttl, all, updatecontracts } = taskArgs;

    const processNetwork = async (chain: CNetwork) => {
      await upload([chain], slotid, ttl);
      if (updatecontracts) {
        const { abi } = await import("../../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json");
        await setDonHostedSecretsVersion(chain, parseInt(slotid), abi);
      }
    };

    if (all) {
      for (const liveChain of liveChains) {
        await processNetwork(liveChain);
      }
    } else {
      await processNetwork(conceroNetworks[hre.network.name]);
    }
  });

export default upload;
