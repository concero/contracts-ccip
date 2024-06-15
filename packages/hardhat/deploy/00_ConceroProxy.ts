import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

const deployConceroProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer, proxyDeployer } = await hre.getNamedAccounts();

  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const implementationAddress = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);

  console.log("Deploying ConceroProxy...");
  const conceroProxyDeployment = (await deploy("ConceroProxy", {
    from: proxyDeployer,
    args: [implementationAddress, proxyDeployer, "0x", deployer],
    log: true,
    autoMine: true,
    gasLimit: 2_000_000,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroProxy deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployConceroProxy");
    updateEnvVariable(
      `CONCEROPROXY_${networkEnvKeys[name]}`,
      conceroProxyDeployment.address,
      "../../../.env.deployments",
    );
  }
};

export default deployConceroProxy;
deployConceroProxy.tags = ["ConceroProxy"];
