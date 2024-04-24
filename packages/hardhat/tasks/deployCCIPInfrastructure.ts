import { task } from "hardhat/config";
import { subscriptionHealthcheck } from "./ensureConsumerAdded";
import { deployContract } from "./deployContract";
import chains from "../constants/CNetworks";
import { execSync } from "child_process";
import { reloadDotEnv } from "../utils/dotenvConfig";
import { setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";

const selectedChains = [chains.optimismSepolia, chains.baseSepolia];
let deployableChains = selectedChains;

task("deploy-ccip-infrastructure", "Deploy the CCIP infrastructure")
  .addOptionalParam("deploy", "Deploy the contract to a specific network", "true")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    if (name !== "localhost" && name !== "hardhat") deployableChains = [chains[name]];

    secretsHealthcheck(deployableChains);
    if (taskArgs.deploy === "true") await deployContract(deployableChains);
    else console.log("Skipping deployment");

    await subscriptionHealthcheck(selectedChains);
    await setContractVariables(selectedChains);
    await fundContract(deployableChains);
  });

function secretsHealthcheck(selectedChains) {
  for (const chain of selectedChains) {
    execSync(`yarn hardhat functions-ensure-don-secrets --network ${chain.name}`, { stdio: "inherit" });
  }
  reloadDotEnv();
}
export default {};
