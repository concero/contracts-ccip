// import { DeployFunction, Deployment } from "hardhat-deploy/types";
// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import { networkEnvKeys } from "../constants/CNetworks";
// import updateEnvVariable from "../utils/updateEnvVariable";
// import log from "../utils/log";
// // import { initialProxyImplementationAddress } from "../constants/deploymentVariables";
// import { getEnvVar } from "../utils/getEnvVar";
//
// REPLACED BY 11_TransparentProxy.ts
// const deployChildProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
//   const { deployer, proxyDeployer } = await hre.getNamedAccounts();
//   const { deploy } = hre.deployments;
//   const { name } = hre.network;
//
//   const implementationAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`);
//
//   console.log("Deploying ChildProxy...");
//   const deployChildProxy = (await deploy("ChildPoolProxy", {
//     from: proxyDeployer,
//     args: [implementationAddress, proxyDeployer, "0x"],
//     log: true,
//     autoMine: true,
//   })) as Deployment;
//
//   if (name !== "hardhat" && name !== "localhost") {
//     log(`ChildPoolProxy deployed to ${name} to: ${deployChildProxy.address}`, "deployChildPoolProxy");
//     updateEnvVariable(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`, deployChildProxy.address, "../../../.env.deployments");
//   }
// };
//
// export default deployChildProxy;
// deployChildProxy.tags = ["ChildPoolProxy"];
