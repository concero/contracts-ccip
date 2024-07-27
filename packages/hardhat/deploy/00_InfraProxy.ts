import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { getClients } from "../tasks/utils/getViemClients";

const deployConceroProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer, proxyDeployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const implementationAddress = getEnvVar(`CONCERO_ORCHESTRATOR_${networkEnvKeys[name]}`);

  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = CNetworks[name];
  const { publicClient } = getClients(dcViemChain, dcUrl);
  // const gasPrice = await publicClient.getGasPrice();

  console.log("Deploying InfraProxy...");
  const conceroProxyDeployment = (await deploy("InfraProxy", {
    from: proxyDeployer,
    args: [implementationAddress, proxyDeployer, "0x"],
    log: true,
    autoMine: true,
    // gasPrice: gasPrice.toString(),
    // gasLimit: "1000000",
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`InfraProxy deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployInfraProxy");
    updateEnvVariable(`CONCERO_PROXY_${networkEnvKeys[name]}`, conceroProxyDeployment.address, "../../../.env.deployments");
  }
};

export default deployConceroProxy;
deployConceroProxy.tags = ["InfraProxy"];
