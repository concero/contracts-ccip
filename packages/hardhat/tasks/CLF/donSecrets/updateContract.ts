// import { SecretsManager } from "@chainlink/functions-toolkit";
// import chains, { networkEnvKeys } from "../../constants/CNetworks";
// import updateEnvVariable from "../../utils/updateEnvVariable";
// import { task } from "hardhat/config";
// import uploadDonSecrets from "./upload";
// import { getClients } from "../utils/switchChain";
// import load from "../../utils/load";
// import { liveChains } from "../concero/deployInfra";
// import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
// import { CNetwork } from "../../types/CNetwork";
// import { getEnvVar } from "../../utils/getEnvVar";
// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import log from "../../utils/log";
//
// export async function updateContract(chains: CNetwork[]) {
//   const { abi } = await load("../artifacts/contracts/ConceroFunctions.sol/ConceroFunctions.json");
//   for (const chain of chains) {
//     const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, viemChain, url, name } = chain;
//     const { signer } = getEthersSignerAndProvider(url);
//
//     if (!functionsGatewayUrls || functionsGatewayUrls.length === 0) throw Error(`No gatewayUrls found for ${name}.`);
//     const { walletClient, publicClient, account } = getFallbackClients(chain);
//     const contract = getEnvVar(`CONCERO_BRIDGE_${networkEnvKeys[name]}`); // grabbing up-to-date var
//
//     const secretsManager = new SecretsManager({
//       signer,
//       functionsRouterAddress: functionsRouter,
//       donId: functionsDonIdAlias,
//     });
//     await secretsManager.initialize();
//
//     const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
//     const allSecrets = [];
//     const res = result.nodeResponses[0];
//
//     if (!res.rows) {
//       return log(`No secrets found for ${name}. Uploading secrets...`, "updateContract");
//       // const {
//       //   slot_id: newSlotId,
//       //   version: newVersion,
//       //   expiration: newExpiration,
//       // } = await uploadDonSecrets({ slotid: 0, ttl: 4320 });
//       // res.rows = [{ slot_id: newSlotId, version: newVersion, expiration: newExpiration }];
//     }
//
//     const row = res.rows.filter(row => row.slot_id === 1)[0];
//     updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, row.version.toString(), "../../../.env.clf");
//     updateEnvVariable(
//       `CLF_DON_SECRETS_EXPIRATION_${networkEnvKeys[name]}`,
//       row.expiration.toString(),
//       "../../../.env.clf",
//     );
//     allSecrets.push(row);
//
//     const { request: setDstConceroContractReq } = await publicClient.simulateContract({
//       address: contract,
//       abi,
//       functionName: "setDonHostedSecretsVersion",
//       account,
//       args: [row.version],
//       chain: viemChain,
//     });
//
//     const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
//     const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
//       hash: setDstConceroContractHash,
//     });
//     log(
//       `Set ${name}:${contract} donHostedSecretsVersion[${name}, ${row.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
//       "updateContract",
//     );
//   }
// }
//
// // run with: bunx clf-donsecrets-updatecontract --network avalancheFuji
// task("clf-donsecrets-updatecontract", "Uploads DON secrets and updates contract variables")
//   .addFlag("all", "List secrets from all chains")
//   .setAction(async taskArgs => {
//     const hre: HardhatRuntimeEnvironment = require("hardhat");
//
//     if (taskArgs.all) await updateContract(liveChains);
//     else await updateContract([chains[hre.network.name]]);
//   });
//
// export default {};
