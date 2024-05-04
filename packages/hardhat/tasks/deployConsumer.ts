// import { task, types } from "hardhat/config";
// import networks from "../constants/CLFnetworks";
// import { Deployment } from "hardhat-deploy/types";
// import { CFunctions } from "../typechain-types";
//
// task("functions-deploy-consumer", "Deploys the FunctionsConsumer contract")
//   .addOptionalParam("verify", "Set to true to verify contract", false, types.boolean)
//   .setAction(async taskArgs => {
//     const { deployer } = await hre.getNamedAccounts();
//     const { deploy } = hre.deployments;
//     const chainId = await hre.getChainId();
//     console.log("chainId", chainId);
//     const deploymentOptions = {
//       31337: {
//         donId: process.env.CLF_DONID_FUJI,
//         router: process.env.CLF_ROUTER_FUJI,
//         chainSelector: "14767482510784806043",
//         subscriptionId: 5810,
//         donHostedSecretsVersion: 1712841282,
//       },
//     };
//     const { router, donId, chainSelector, subscriptionId, donHostedSecretsVersion } = deploymentOptions[chainId];
//
//     console.log(`Deploying FunctionsConsumer contract to ${hre.network.name}`);
//
//     const functionsRouter = networks[hre.network.name]["functionsRouter"];
//     const donIdBytes32 = hre.ethers.encodeBytes32String(networks[hre.network.name]["donId"]);
//
//     console.log("\n__Compiling Contracts__");
//     await run("compile");
//
//     const overrides = {};
//     // If specified, use the gas price from the network config instead of Ethers estimated price
//     if (networks[hre.network.name].gasPrice) {
//       overrides.gasPrice = networks[hre.network.name].gasPrice;
//     }
//     // If specified, use the nonce from the network config instead of automatically calculating it
//     if (networks[hre.network.name].nonce) {
//       overrides.nonce = networks[hre.network.name].nonce;
//     }
//
//     const deployment = (await deploy("CFunctions", {
//       from: deployer,
//       log: true,
//       args: [router, donId, subscriptionId, donHostedSecretsVersion, chainSelector],
//       autoMine: true,
//     })) as Deployment;
//
//     console.log("Deployed FunctionsConsumer contract to:", deployment.transactionHash);
//     const consumerContract = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
//     // console.log(`\nWaiting ${networks[hre.network.name].confirmations} blocks for transaction ${deployment.transactionHash} to be confirmed...`);
//     // console.log("\nDeployed FunctionsConsumer contract to:", deployment.address);
//     if (hre.network.name === "localFunctionsTestnet") return;
//
//     const verifyContract = taskArgs.verify;
//     if (
//       hre.network.name !== "localFunctionsTestnet" &&
//       verifyContract &&
//       !!networks[hre.network.name].verifyApiKey &&
//       networks[hre.network.name].verifyApiKey !== "UNSET"
//     ) {
//       try {
//         console.log("\nVerifying contract...");
//         await run("verify:verify", {
//           address: deployment.address,
//           constructorArguments: [functionsRouter, donIdBytes32],
//         });
//         console.log("Contract verified");
//       } catch (error) {
//         if (!error.message.includes("Already Verified")) {
//           console.log("Error verifying contract.  Ensure you are waiting for enough confirmation blocks, delete the build folder and try again.");
//           console.log(error);
//         } else {
//           console.log("Contract already verified");
//         }
//       }
//     } else if (verifyContract && hre.network.name !== "localFunctionsTestnet") {
//       console.log("\nScanner API key is missing. Skipping contract verification...");
//     }
//
//     console.log(`\nFunctionsConsumer contract deployed to ${deployment.address} on ${hre.network.name}`);
//   });
