import { networkEnvKeys } from "../constants/CNetworks";
import { abi, bytecode } from "../artifacts/contracts/Concero.sol/Concero.json";
import updateEnvVariable from "../utils/updateEnvVariable";
import { CNetwork } from "../types/CNetwork";
import { getClients } from "./switchChain";
import { execSync } from "child_process";
export async function deployContract(chains: CNetwork[]) {
  execSync(`bunx hardhat compile`, { stdio: "inherit" });

  for (const chain of chains) {
    const { name, viemChain, linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, conceroChainIndex, url } = chain;
    const donHostedSecretsVersion = process.env[`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`]; // gets up-to-date env variable

    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const hash = await walletClient.deployContract({
      abi,
      account,
      bytecode,
      args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter],
    });

    const { contractAddress, cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
    updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[name]}`, contractAddress, "../../../.env");
    console.log(`Deployed to ${name} at address ${contractAddress}\nTXHash: ${hash}\nGas used:${cumulativeGasUsed.toString()}`);
    // ensureFunctionsConsumerAdded(functionsSubId, contractAddress, networkName);
    // const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, contractAddress, functionsSubIds[0]);
    // console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
  }
}
