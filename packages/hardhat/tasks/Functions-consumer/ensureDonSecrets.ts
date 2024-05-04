import { SecretsManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import updateEnvVariable from "../../utils/updateEnvVariable";
import { networkEnvKeys } from "../../constants/CNetworks";
import { task } from "hardhat/config";
import { uploadSecretsToDon } from "./uploadSecretsToDon";
import { getClients } from "../switchChain";
import load from "../../utils/load";

// run with: bunx hardhat functions-list-don-secrets --network avalancheFuji
task("functions-ensure-don-secrets", "Displays encrypted secrets hosted on the DON").setAction(async taskArgs => {
  const { abi } = await load("../artifacts/contracts/Concero.sol/Concero.json");
  const { name } = hre.network;
  const signer = await hre.ethers.getSigner();
  const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, viemChain, url } = chains[name];

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

  const { walletClient, publicClient, account } = getClients(viemChain, url);
  const contract = process.env[`CONCEROCCIP_${networkEnvKeys[name]}`]; // grabbing up-to-date var

  const res = result.nodeResponses[0];
  if (!res.rows) {
    console.log(`No secrets found for ${name}. Uploading secrets...`);
    await uploadSecretsToDon({ slotid: 0, ttl: 4320 });
  }

  if (res.rows) {
    const row = res.rows[0];
    updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, row.version, "../../../.env.clf");
    updateEnvVariable(`CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[name]}`, row.expiration, "../../../.env.clf");
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
});
export default {};
