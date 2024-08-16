// import { Deployment } from "hardhat-deploy/types";
// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import chains, { networkEnvKeys } from "../constants/CNetworks";
// import updateEnvVariable from "../utils/updateEnvVariable";
// import log from "../utils/log";
// import getHashSum from "../utils/getHashSum";
// import path from "path";
// import fs from "fs";
// import { getEnvVar } from "../utils/getEnvVar";
// import { ethersV6CodeUrl } from "../constants/functionsJsCodeUrls";
//
// interface ConstructorArgs {
//   functionsDonId?: number;
//   functionsSubIds?: number;
//   slotId?: number; //Need to create this
//   donHostedSecretsVersion?: string;
//   hashSum?: string; //Need to create this
//   etherHashSum?: string;
//   functionsRouter?: string;
//   parentProxyAddress?: string;
//   owner?: string;
// }
//
// const deployConceroAutomation: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
//   async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
//     const { deployer } = await hre.getNamedAccounts();
//     const { deploy } = hre.deployments;
//     const { name, live } = hre.network;
//
//     const { functionsRouter, functionsDonId, functionsSubIds, donHostedSecretsVersion, type } = chains[name];
//
//     const jsPath = "./tasks/CLFScripts";
//
//     function getJS(jsPath: string, type: string): string {
//       const dist = path.join(jsPath, "dist", `${type}.min.js`);
//       return fs.readFileSync(dist, "utf8");
//     }
//
//     const defaultArgs = {
//       functionsDonId: functionsDonId,
//       functionsSubIds: functionsSubIds,
//       functionsSlotId: constructorArgs.slotId || 0,
//       donHostedSecretsVersion: donHostedSecretsVersion,
//       hashSum: getHashSum(getJS(jsPath, "pool/getTotalBalance")),
//       etherHashSum: getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
//       functionsRouter: functionsRouter,
//       parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
//       owner: deployer,
//     };
//
//     const args = { ...defaultArgs, ...constructorArgs };
//
//     console.log("Deploying ConceroAutomation...");
//     const deployConceroAutomation = (await deploy("ConceroAutomation", {
//       from: deployer,
//       args: [
//         args.functionsDonId,
//         args.functionsSubIds[0],
//         args.functionsSlotId,
//         args.functionsRouter,
//         args.parentProxyAddress,
//         args.owner,
//       ],
//       log: true,
//       autoMine: true,
//     })) as Deployment;
//
//     if (live) {
//       log(`ConceroAutomation deployed to ${name} to: ${deployConceroAutomation.address}`, "deployConceroAutomation");
//       updateEnvVariable(
//         `CONCERO_AUTOMATION_${networkEnvKeys[name]}`,
//         deployConceroAutomation.address,
//         `deployments.${type}`,
//       );
//     }
//   };
//
// export default deployConceroAutomation;
// deployConceroAutomation.tags = ["ConceroAutomation"];
