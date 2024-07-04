import { getEthersSignerAndProvider } from "../../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";
import log from "../../../utils/log";
import CNetworks from "../../../constants/CNetworks";

export async function getSecretsBySlotId(chainName: string, slotId: number) {
  const chain = CNetworks[chainName];
  const {
    functionsRouter: dcFunctionsRouter,
    functionsDonIdAlias: dcFunctionsDonIdAlias,
    functionsGatewayUrls: dcFunctionsGatewayUrls,
    url: dcUrl,
    name: dcName,
  } = chain;
  const { signer: dcSigner } = getEthersSignerAndProvider(dcUrl);

  const secretsManager = new SecretsManager({
    signer: dcSigner,
    functionsRouterAddress: dcFunctionsRouter,
    donId: dcFunctionsDonIdAlias,
  });
  await secretsManager.initialize();

  const { result } = await secretsManager.listDONHostedEncryptedSecrets(dcFunctionsGatewayUrls);
  const nodeResponse = result.nodeResponses[0];
  if (!nodeResponse.rows) return log(`No secrets found for ${dcName}.`, "updateContract");

  const rowBySlotId = nodeResponse.rows.find(row => row.slot_id === slotId);
  if (!rowBySlotId) return log(`No secrets found for ${dcName} at slot ${slotId}.`, "updateContract");

  return rowBySlotId;
}
