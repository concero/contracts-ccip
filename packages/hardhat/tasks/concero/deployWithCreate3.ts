// import CNetworks, { networkEnvKeys } from "../../constants/CNetworks";
// import { getClients } from "../utils/getViemClients";
// import { getEnvVar } from "../../utils/getEnvVar";
// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import { task } from "hardhat/config";
// import load from "../../utils/load";
// import { keccak256 } from "viem";
//
// async function deployWithCreate3(filename: string) {
//   const hre: HardhatRuntimeEnvironment = require("hardhat");
//
//   const { bytecode } = await load(`../artifacts/contracts/${filename}.sol/${filename}.json`);
//
//   const initCodeHash = keccak256(bytecode);
//   console.log("Initialization Code Hash:", initCodeHash);
//   return
//   if (!CNetworks[hre.network.name]) return console.error("Network not supported");
//
//
//   const { viemChain, url, name } = CNetworks[hre.network.name];
//   const { walletClient, publicClient } = getFallbackClients(chain);
//
//   let salt;
//   let regex
//
//   const deploymentReq = await publicClient.simulateContract({
//     // address: getEnvVar(`CREATE3_FACTORY_${networkEnvKeys[name]}`),
//     address: "0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1" //lifi contract factory
//     abi: [{"inputs":[{"internalType":"bytes32","name":"salt","type":"bytes32"},{"internalType":"bytes","name":"creationCode","type":"bytes"}],"name":"deploy","outputs":[{"internalType":"address","name":"deployed","type":"address"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"address","name":"deployer","type":"address"},{"internalType":"bytes32","name":"salt","type":"bytes32"}],"name":"getDeployed","outputs":[{"internalType":"address","name":"deployed","type":"address"}],"stateMutability":"view","type":"function"}]
//     functionName: "deploy",
//     args: [SALT, bytecode],
//   });
//
// }
//
// task("deploy-with-create3", "Deploy a contract using create3")
//   .addParam("contract", "The contract to deploy", undefined)
//   .setAction(async taskArgs => {
//     await deployWithCreate3(taskArgs.contract);
//   });
//
// export default deployWithCreate3;
