import { task, types } from "hardhat/config";
import { execSync } from "child_process";
import { liveChains } from "../liveChains";

const executeCommand = (command: string) => {
  execSync(command, { stdio: "inherit" });
};

task("deploy-all-pools", "Deploy all pool")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("testnet", "is testnet deploy")
  .setAction(async taskArgs => {
    const slotId = parseInt(taskArgs.slotid);
    executeCommand(
      `yarn hardhat deploy-parent-pool --network ${taskArgs.testnet ? "baseSepolia" : "base"} --slotid ${slotId} --deployproxy --skipdeploy --skipsetvars`,
    );

    executeCommand(`yarn hardhat deploy-automations --network base --slotid ${slotId}`);

    for (const chain of liveChains) {
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name} --deployproxy --skipdeploy --skipsetvars`);
    }

    for (const chain of liveChains) {
      executeCommand(`yarn hardhat deploy-child-pool --network ${chain.name}`);
    }

    executeCommand(
      `yarn hardhat deploy-parent-pool --network ${taskArgs.testnet ? "baseSepolia" : "base"} --slotid ${slotId}`,
    );
  });

export default {};
