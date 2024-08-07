import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroAutomation from "../../../deploy/06_ConceroAutomation";
import { setAutomationsVariables } from "./setAutomationsVariables";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import { getEnvVar } from "../../../utils/getEnvVar";
import { execSync } from "child_process";
import addCLFConsumer from "../../sub/add";

task("deploy-pool-clfcla", "Deploy the automations")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addFlag("skipsetvars", "Skip setting the variables")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addOptionalParam("forwarder", "Automations forwarder address", undefined, types.string)
  .setAction(async taskArgs => {
    execSync("yarn compile", { stdio: "inherit" });
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);

    if (!taskArgs.skipdeploy) {
      await deployConceroAutomation(hre, { slotId });

      const chain = CNetworks[hre.network.name];
      const automationContractAddress = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[hre.network.name]}`);
      await addCLFConsumer(chain, [automationContractAddress], chain.functionsSubIds[0]);
    }
    if (!taskArgs.skipsetvars) await setAutomationsVariables(hre, slotId, taskArgs.forwarder);
  });

export default {};
