import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroAutomation from "../../../deploy/06_ConceroAutomation";
import { setAutomationsVariables } from "./setAutomationsVariables";
import CNetworks from "../../../constants/CNetworks";
import { getEnvVar } from "../../../utils/getEnvVar";
import { execSync } from "child_process";
import addCLFConsumer from "../../sub/add";

task("deploy-automations", "Deploy the automations")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addOptionalParam(
    "automationsforwarder",
    "Automations forwarder",
    "0xE204f83a342259F9B9C118A7c94a7B635c641E60",
    types.string,
  )
  .setAction(async taskArgs => {
    execSync("yarn compile", { stdio: "inherit" });
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);

    if (!taskArgs.skipdeploy) {
      await deployConceroAutomation(hre, { slotId });

      execSync(`yarn hardhat deploy-parent-pool --network baseSepolia --slotid ${slotId} --skipsetvars`, {
        stdio: "inherit",
      });

      const chain = CNetworks[hre.network.name];
      const automationContractAddress = getEnvVar("CONCERO_AUTOMATION_BASE_SEPOLIA");
      await addCLFConsumer(chain, [automationContractAddress], chain.functionsSubIds[0]);
    }

    await setAutomationsVariables(hre, slotId, taskArgs.automationsforwarder);
  });

export default {};
