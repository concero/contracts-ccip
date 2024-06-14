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
  const conceroProxyDeployment = (await deploy("ConceroProxy", {
    from: proxyDeployer,
    args: ["0x3055cC530B8cF18fD996545EC025C4e677a1dAa3", proxyDeployer, "0x"],
    log: true,
    autoMine: true,
    gasLimit: 2_000_000,
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
