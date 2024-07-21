import { task } from "hardhat/config";
import { liveChains } from "./liveChains";
import { execSync } from "child_process";

task(
  "update-all-infra-implementations",
  "Script to update all infrastructure implementations without setting variables",
).setAction(async taskArgs => {
  for (const chain of liveChains) {
    const networkName = chain.name;
    execSync(`yarn hardhat deploy-infra --network ${networkName} --skipsetvars`, { stdio: "inherit" });
  }
});

export default {};
