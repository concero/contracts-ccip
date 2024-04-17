import { CCombined } from "../artifacts/contracts/CCombined.sol";
import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../constants/CNetworks";

/* run with: yarn deploy --network avalancheFuji --tags CFunctions */
const deployCCombined: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  // if (!chains[name]) throw new Error(`Chain ${name} not supported`);
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion } = chains[name];

  const deployment = (await deploy("CCombined", {
    from: deployer,
    log: true,
    args: [linkToken, ccipRouter, functionsRouter, functionsDonId, functionsSubIds[0], donHostedSecretsVersion, chainSelector],
    autoMine: true,
  })) as Deployment;

  const cCombined = await hre.ethers.getContract<CCombined>("CCombined", deployer);
  const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, deployment.address, functionsSubIds[0]);
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

export default deployCCombined;
deployCCombined.tags = ["CCombined"];
