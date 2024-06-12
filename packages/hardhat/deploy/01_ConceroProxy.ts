import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";

const deployConceroProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { proxyDeployer } = await hre.getNamedAccounts();

  const { deploy } = hre.deployments;
  const { name } = hre.network;

  console.log("Deploying ConceroProxy...");
  const conceroProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
    from: proxyDeployer,
    args: ["0x68bF17c2c22A90489163c9717ae2ad8eAa9d43aE", proxyDeployer, 0x0],
    log: true,
    autoMine: true,
    gasLimit: 300_000,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroPool deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployConceroProxy");
    updateEnvVariable(
      `CONCEROPROXY_${networkEnvKeys[name]}`,
      conceroProxyDeployment.address,
      "../../../.env.deployments",
    );
  }
};

export default deployConceroProxy;
deployConceroProxy.tags = ["ConceroProxy"];
