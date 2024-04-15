import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deploymentOptions from "../constants/CLFChains";

const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  if (!deploymentOptions[hre.network.name]) throw new Error(`Chain ${hre.network.name} not supported`);
  const { router, donId, chainSelector, subscriptionId, donHostedSecretsVersion } = deploymentOptions[hre.network.name];

  const deployment = (await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [router, donId, subscriptionId, donHostedSecretsVersion, chainSelector],
    autoMine: true,
  })) as Deployment;

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
  const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(router, deployment.address, subscriptionId);
  console.log(`CL Functions Consumer deployed successfully at ${CLFunctionsConsumerTXHash}`);

  // exec(
  //   `npx hardhat verify --network polygonMumbai ${contractAddress} ${router} ${donId} ${subscriptionId} ${donHostedSecretsVersion} ${chainSelector}`,
  //   (error, stdout, stderr) => {
  //     if (error) {
  //       console.error(`ERROR: ${error}`);
  //       return;
  //     }
  //     console.log(`SUCCESS`);
  //   },
  // );
};

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
