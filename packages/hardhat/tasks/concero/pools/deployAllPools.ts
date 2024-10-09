import { task, types } from "hardhat/config";
import { execSync } from "child_process";
import { liveChains } from "../../../constants";

const executeCommand = (command: string) => {
  execSync(command, { stdio: "inherit" });
};

task("deploy-all-pools", "Deploy all pool")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("mainnet", "is mainnet deploy")
  .setAction(async taskArgs => {
    const slotId = parseInt(taskArgs.slotid);
    const parentPoolNetwork = taskArgs.mainnet ? "base" : "baseSepolia";

    executeCommand(`yarn hardhat clean`);

    executeCommand(
      `yarn hardhat deploy-parent-pool --network ${parentPoolNetwork} --slotid ${slotId} --deployproxy --uploadsecrets`,
    );

    for (const chain of liveChains) {
      if (chain.name === "base" || chain.name === "baseSepolia") continue;
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name} --deployproxy`);
    }

    for (const chain of liveChains) {
      if (chain.name === "base" || chain.name === "baseSepolia") continue;
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name} --setvars --deployimplementation`);
    }

    executeCommand(`yarn hardhat deploy-lp-token --network ${parentPoolNetwork}`);

    executeCommand(
      `yarn hardhat deploy-parent-pool --network ${parentPoolNetwork} --slotid ${slotId} --setvars --deployimplementation`,
    );

    //todo: TESTNET ONLY should send 0.1 LINK to parentPool
    // rebuild functions js code and push to github!!!
  });

export default {};
