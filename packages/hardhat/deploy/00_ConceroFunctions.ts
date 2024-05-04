import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../constants/CNetworks";

/* run with: yarn deploy --network avalancheFuji --tags CFunctions */
const deployConceroFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  // if (!chains[name]) throw new Error(`Chain ${name} not supported`);
  const { functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion } = chains[name];
  const chainIndex = "0";
  const deployment = (await deploy("ConceroFunctions", {
    from: deployer,
    log: true,
    args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, chainIndex],
    autoMine: true,
  })) as Deployment;

  // const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
  if (name !== "hardhat") {
    const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(
      functionsRouter,
      deployment.address,
      functionsSubIds[0],
    );
    console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
  }
  // exec(
  //   `npx hardhat verify --network polygonMumbai ${contractAddress} ${router} ${donId} ${functionsSubId} ${donHostedSecretsVersion} ${chainSelector}`,
  //   (error, stdout, stderr) => {
  //     if (error) {
  //       console.error(`ERROR: ${error}`);
  //       return;
  //     }
  //     console.log(`SUCCESS`);
  //   },
  // );
};

export default deployConceroFunctions;
deployConceroFunctions.tags = ["ConceroFunctions"];
