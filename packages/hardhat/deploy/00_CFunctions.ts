import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { CL_FUNCTIONS_ROUTER_MUMBAI, CL_FUNCTIONS_DON_ID_MUMBAI } = process.env;
  const { network } = hre;

  const chainSelectorsMap = {
    8001: 12532609583862916517n,
    43113: 14767482510784806043n,
  };

  await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [
      CL_FUNCTIONS_ROUTER_MUMBAI,
      CL_FUNCTIONS_DON_ID_MUMBAI,
      1437,
      1712503865,
      "0x4200A2257C399C1223f8F3122971eb6fafaaA976",
      "0x3A684e72D220Ce842354bebf9AfFCdA34EE27D82",
      "12532609583862916517",
    ],
    autoMine: true,
  });

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
};

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
