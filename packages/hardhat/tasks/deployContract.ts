import { execSync } from "child_process";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, http } from "viem";
import { abi, bytecode } from "../artifacts/contracts/Concero.sol/Concero.json";
import updateEnvVariable from "../utils/updateEnvVariable";

export async function deployContract(networkName: string, networks) {
  execSync(`bunx hardhat compile`, { stdio: "inherit" });
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion, conceroChainIndex, url } =
    chains[networkName];

  const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
  const walletClient = createWalletClient({ transport: http(url), chain: networks[networkName], account });
  const publicClient = createPublicClient({ transport: http(url), chain: networks[networkName] });

  const hash = await walletClient.deployContract({
    abi,
    account,
    bytecode,
    args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter],
  });

  const { contractAddress, cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
  updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[networkName]}`, contractAddress, "../../../.env");
  console.log(`Deployed to ${networkName} at address ${contractAddress}\nTXHash: ${hash}\nGas used:${cumulativeGasUsed.toString()}`);
  // ensureFunctionsConsumerAdded(functionsSubId, contractAddress, networkName);
  // const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, contractAddress, functionsSubIds[0]);
  // console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
}
