import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroAutomation from "../../../deploy/06_ConceroAutomation";
import { setAutomationsVariables } from "./setAutomationsVariables";

task("deploy-automations", "Deploy the automations")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addOptionalParam(
    "automationsforwarder",
    "Automations forwarder",
    "0x39d395a31c379579d9D172C2181dE2DE241095D1",
    types.string,
  )
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);

    if (!taskArgs.skipdeploy) {
      await deployConceroAutomation(hre);
    }

    await setAutomationsVariables(hre, slotId, taskArgs.automationsforwarder);
  });

export default {};
