import { task } from "hardhat/config";
import { subscriptionHealthcheck } from "./ensureConsumerAdded";
import { deployContract } from "./deployContract";
import chains from "../constants/CNetworks";
import { execSync } from "child_process";
import dotenv from "dotenv";
import configureDotEnv, { reloadDotEnv } from "../utils/dotenvConfig";
import dotenvConfig from "../utils/dotenvConfig";
/* todo:
- Make sure secrets for chain are set
 */

const selectedChains = [chains.arbitrumSepolia, chains.optimismSepolia, chains.baseSepolia];

task("deploy-ccip-infrastructure", "Deploy the CCIP infrastructure")
  .addOptionalParam("deploy", "Deploy the contract to a specific network", "true")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    secretsHealthcheck(selectedChains);
    if (taskArgs.deploy === "true") {
      if (name !== "localhost" && name !== "hardhat") {
        console.log("deploying to", chains[name].name);
        await deployContract(chains[name], selectedChains);
      } else {
        for (const chain of selectedChains) {
          await deployContract(chain, selectedChains);
        }
      }
    } else {
      console.log("Skipping deployment");
    }

    await subscriptionHealthcheck(selectedChains);
    // await setContractVariables(networks);
  });

function secretsHealthcheck(selectedChains) {
  for (const chain of selectedChains) {
    execSync(`yarn hardhat functions-ensure-don-secrets --network ${chain.name}`, { stdio: "inherit" });
  }
  reloadDotEnv();
}
export default {};
