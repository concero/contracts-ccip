import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { CL_FUNCTIONS_ROUTER_MUMBAI, CL_FUNCTIONS_DON_ID_MUMBAI } = process.env;

  await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [CL_FUNCTIONS_ROUTER_MUMBAI, CL_FUNCTIONS_DON_ID_MUMBAI, 1437, 1712503865],
    autoMine: true,
  });

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
};

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
// yarn deploy --tags CFunctions
