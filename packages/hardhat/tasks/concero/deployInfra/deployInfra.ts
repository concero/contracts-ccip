import { task, types } from "hardhat/config";
import chains, { networkEnvKeys } from "../../../constants/CNetworks";
import { setConceroProxyDstContracts, setContractVariables } from "./setContractVariables";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../../types/CNetwork";
import log from "../../../utils/log";
import uploadDonSecrets from "../../donSecrets/upload";
import deployConcero from "../../../deploy/04_ConceroBridge";
import { execSync } from "child_process";
import { liveChains } from "../liveChains";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";
import deployConceroOrchestrator from "../../../deploy/05_ConceroOrchestrator";
import addCLFConsumer from "../../sub/add";
import { getEnvVar } from "../../../utils/getEnvVar";
import deployInfraProxy from "../../../deploy/00_InfraProxy";
import { setProxyImplementation } from "./setProxyImplementation";

let deployableChains: CNetwork[] = liveChains;

// 3 months in sec = 7776000

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("skipsetvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Upload DON-hosted secrets")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;

    if (name !== "localhost" && name !== "hardhat") {
      deployableChains = [chains[name]];
    }

    if (taskArgs.deployproxy) {
      await deployInfraProxy(hre);
      const proxyAddress = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[name]}`);
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
