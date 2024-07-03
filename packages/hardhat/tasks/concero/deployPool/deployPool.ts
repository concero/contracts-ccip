import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../../../constants/CNetworks";
import deployConceroProxy from "../../../deploy/00_InfraProxy";
import { getEnvVar } from "../../../utils/getEnvVar";
import addCLFConsumer from "../../sub/add";
import log from "../../../utils/log";
import { execSync } from "child_process";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";
import deployConcero from "../../../deploy/04_Concero";
import deployConceroOrchestrator from "../../../deploy/05_ConceroOrchestrator";
import { setProxyImplementation } from "../deployInfra/setProxyImplementation";
import { liveChains } from "../liveChains";
import uploadDonSecrets from "../../donSecrets/upload";
import { setConceroProxyDstContracts, setContractVariables } from "../setInfraVariables/setContractVariables";
import { CNetwork } from "../../../types/CNetwork";

task("deploy-pool", "Deploy the pool")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("skipsetvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Set the contract variables")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;
    let deployableChains: CNetwork[] = liveChains;

    if (name !== "localhost" && name !== "hardhat") {
      deployableChains = [chains[name]];
    }

    if (taskArgs.deployproxy) {
      await deployConceroProxy(hre);
      const proxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[name]}`);
      const { functionsSubIds } = chains[name];
      await addCLFConsumer(chains[name], [proxyAddress], functionsSubIds[0]);
    }

    if (taskArgs.skipdeploy) {
      log("Skipping deployment", "deploy-infra");
    } else {
      execSync("yarn compile", { stdio: "inherit" });

      await deployConceroDexSwap(hre);
      await deployConcero(hre, { slotId });
      await deployConceroOrchestrator(hre);
      await setProxyImplementation(hre, liveChains);

      if (taskArgs.deployproxy) await setConceroProxyDstContracts(liveChains);
    }

    if (!taskArgs.skipsetvars) {
      if (taskArgs.uploadsecrets) {
        await uploadDonSecrets(deployableChains, slotId, 4320);
      }
      await setContractVariables(liveChains, deployableChains, slotId, taskArgs.uploadsecrets);

      // await fundSubscription(liveChains);
      // await fundContract(deployableChains);
    }
  });

export default {};
