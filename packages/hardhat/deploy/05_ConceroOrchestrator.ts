import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { messengers } from "../constants/deploymentVariables";

const deployConceroOrchestrator: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const { linkToken, ccipRouter, functionsRouter, conceroChainIndex } = chains[name];
  const conceroDexSwapAddress = getEnvVar(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`);
  const conceroAddress = getEnvVar(`CONCERO_BRIDGE_${networkEnvKeys[name]}`);
  const conceroPoolAddress =
    name === "base" || name === "baseSepolia"
      ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`)
      : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`);

  const conceroProxyAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`);

  console.log("Deploying ConceroOrchestrator...");

  const conceroProxyDeployment = (await deploy("Orchestrator", {
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

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroOrchestrator deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployConceroOrchestrator");
    updateEnvVariable(
      `CONCERO_ORCHESTRATOR_${networkEnvKeys[name]}`,
      conceroProxyDeployment.address,
      "../../../.env.deployments",
    );
  }
};

export default deployConceroOrchestrator;
deployConceroOrchestrator.tags = ["ConceroOrchestrator"];
