import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const chainId = await hre.getChainId();

  const deploymentOptions = {
    80001: {
      router: process.env.CL_FUNCTIONS_ROUTER_MUMBAI,
      donId: process.env.CL_FUNCTIONS_DON_ID_MUMBAI,
      chainSelector: 12532609583862916517n,
      subscriptionId: 1437,
      donHostedSecretsVersion: 1712770854,
    },
    43113: {
      donId: process.env.CL_FUNCTIONS_DON_ID_FUJI,
      router: process.env.CL_FUNCTIONS_ROUTER_FUJI,
      chainSelector: 14767482510784806043n,
      subscriptionId: 1437,
      donHostedSecretsVersion: 1712770854,
    },
  };

  if (!deploymentOptions[chainId]) throw new Error(`ChainId ${chainId} not supported`);
  const { router, donId, chainSelector, subscriptionId, donHostedSecretsVersion } = deploymentOptions[chainId];

  await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [router, donId, subscriptionId, donHostedSecretsVersion, chainSelector],
    autoMine: true,
  });

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
};

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
