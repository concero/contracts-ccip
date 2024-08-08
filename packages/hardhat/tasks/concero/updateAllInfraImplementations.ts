import { task } from "hardhat/config";
import { mainnetChains, testnetChains } from "./liveChains";
import { execSync } from "child_process";

task(
  "update-all-infra-implementations",
  "Script to update all infrastructure implementations without setting variables",
)
  .addFlag("testnet")
  .setAction(async taskArgs => {
    const chains = taskArgs.testnet ? testnetChains : mainnetChains;

    for (const chain of chains) {
      const networkName = chain.name;
      //todo: this can be done in parallel
      execSync(`yarn hardhat deploy-infra --network ${networkName} --skipsetvars`, { stdio: "inherit" });
    }
  });
export default {};
