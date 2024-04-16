import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../constants/CNetworks";

/* run with: yarn deploy --network avalancheFuji --tags CFunctions */
const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  if (!chains[name]) throw new Error(`Chain ${name} not supported`);
  const { functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion } = chains[name];

  const deployment = (await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [functionsRouter, functionsDonId, functionsSubIds[0], donHostedSecretsVersion, chainSelector],
    autoMine: true,
  })) as Deployment;

  // const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
  const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, deployment.address, functionsSubId);

  console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);

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

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
