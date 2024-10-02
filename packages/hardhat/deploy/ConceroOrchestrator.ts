import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/cNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";
import { messengers } from "../constants";

const deployConceroOrchestrator: (hre: HardhatRuntimeEnvironment) => Promise<void> = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const { functionsRouter, conceroChainIndex, type } = chains[name];

  const conceroDexSwapAddress = getEnvVar(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`);
  const conceroAddress = getEnvVar(`CONCERO_BRIDGE_${networkEnvKeys[name]}`);

  //todo: fix this
  const conceroPoolAddress =
    name === "base" || name === "baseSepolia"
      ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`)
      : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`);

  const conceroProxyAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`);

  log("Deploying...", "ConceroOrchestrator", name);

  const conceroProxyDeployment = (await deploy("InfraOrchestrator", {
    from: deployer,
    args: [
      functionsRouter,
      conceroDexSwapAddress,
      conceroAddress,
      conceroPoolAddress,
      conceroProxyAddress,
      conceroChainIndex,
      messengers,
    ],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`Deployed at: ${conceroProxyDeployment.address}`, "ConceroOrchestrator", name);
    updateEnvVariable(
      `CONCERO_ORCHESTRATOR_${networkEnvKeys[name]}`,
      conceroProxyDeployment.address,
      `deployments.${type}`,
    );
  }
};

export default deployConceroOrchestrator;
deployConceroOrchestrator.tags = ["ConceroOrchestrator"];
