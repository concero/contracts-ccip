// import { DeployFunction, Deployment } from "hardhat-deploy/types";
// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
// import updateEnvVariable from "../utils/updateEnvVariable";
// import log from "../utils/log";
// import { getClients } from "../tasks/utils/getViemClients";
// import { initialProxyImplementationAddress } from "../constants/deploymentVariables";
//
// REPLACED BY 11_TransparentProxy.ts
// const deployConceroProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
//   const { deployer, proxyDeployer } = await hre.getNamedAccounts();
//   const { deploy } = hre.deployments;
//   const { name, live } = hre.network;
//
//   const { url: dcUrl, viemChain: dcViemChain, name: dcName } = CNetworks[name];
//   const { publicClient } = getClients(dcViemChain, dcUrl);
//   // const gasPrice = await publicClient.getGasPrice();
//
//   console.log("Deploying InfraProxy...");
//   const conceroProxyDeployment = (await deploy("InfraProxy", {
//     from: proxyDeployer,
//     args: [initialProxyImplementationAddress, proxyDeployer, "0x"],
//     log: true,
//     autoMine: true,
//     // gasPrice: gasPrice.toString(),
//     // gasLimit: "1000000",
//   })) as Deployment;
//
//    if (live) {
//     log(`InfraProxy deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployInfraProxy");
//     updateEnvVariable(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`, conceroProxyDeployment.address, "../../../.env.deployments");
//   }
// };
//
// export default deployConceroProxy;
// deployConceroProxy.tags = ["InfraProxy"];
