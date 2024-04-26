import { task } from "hardhat/config";
import { subscriptionHealthcheck } from "./ensureConsumerAdded";
import { deployContract } from "./deployContract";
import chains from "../constants/CNetworks";
import { execSync } from "child_process";
import { reloadDotEnv } from "../utils/dotenvConfig";
import { setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";

export const selectedChains = [chains.optimismSepolia, chains.baseSepolia];
export let deployableChains = selectedChains;

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
    //todo: allowance of link & BNM
  });

function secretsHealthcheck(selectedChains) {
  for (const chain of selectedChains) {
    execSync(`yarn hardhat functions-ensure-don-secrets --network ${chain.name}`, { stdio: "inherit" });
  }
  reloadDotEnv();
}

task("functions-secrets-healthcheck", "Ensures secrets are hosted on the DON for each network").setAction(async taskArgs => {
  secretsHealthcheck(selectedChains);
});

export default {};
