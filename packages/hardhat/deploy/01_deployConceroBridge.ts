import { ConceroBridge } from "../artifacts/contracts/ConceroBridge.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployConceroBridge: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI } = process.env;

  await deploy("ConceroBridge", {
    from: deployer,
    log: true,
    args: [LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI, "0x4200A2257C399C1223f8F3122971eb6fafaaA976"],
    autoMine: true,
  });

  const conceroBridge = await hre.ethers.getContract<ConceroBridge>("ConceroBridge", deployer);
};

export default deployConceroBridge;
deployConceroBridge.tags = ["ConceroBridge"];
// yarn deploy --tags CFunctions
