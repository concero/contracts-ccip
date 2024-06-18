import { task, types } from "hardhat/config";
import { fundSubscription } from "./fundSubscription";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import { setConceroProxyDstContracts, setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../types/CNetwork";
import log from "../../utils/log";
import uploadDonSecrets from "../donSecrets/upload";
import deployConcero from "../../deploy/03_Concero";
import { execSync } from "child_process";
import { liveChains } from "./liveChains";
import { setProxyImplementation } from "./setProxyImplementation";
import deployConceroDexSwap from "../../deploy/02_ConceroDexSwap";
import deployConceroOrchestrator from "../../deploy/04_ConceroOrchestrator";
import addCLFConsumer from "../sub/add";
import { getEnvVar } from "../../utils/getEnvVar";
import deployConceroProxy from "../../deploy/00_ConceroProxy";

let deployableChains: CNetwork[] = liveChains;

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("deployproxy", "Deploy the proxy")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;

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

      // if (taskArgs.deployproxy)
      await setConceroProxyDstContracts(liveChains);
    }

    await uploadDonSecrets(deployableChains, slotId, 4320);
    await setContractVariables(liveChains, deployableChains, slotId);
    await fundSubscription(liveChains);
    await fundContract(deployableChains);
  });

export default {};
