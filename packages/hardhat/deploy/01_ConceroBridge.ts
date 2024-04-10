import { ConceroCCIP } from "../artifacts/contracts/ConceroCCIP.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployConceroBridge: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI } = process.env;

  console.log("LINK_MUMBAI", LINK_MUMBAI);
  console.log("CL_CCIP_ROUTER_MUMBAI", CL_CCIP_ROUTER_MUMBAI);

  await deploy("ConceroCCIP", {
    from: deployer,
    log: true,
    args: [LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI, "0x4200A2257C399C1223f8F3122971eb6fafaaA976"],
    autoMine: true,
  });

  const conceroBridge = await hre.ethers.getContract<ConceroCCIP>("ConceroCCIP", deployer);
};

export default deployConceroBridge;
deployConceroBridge.tags = ["ConceroCCIP"];
// yarn deploy --tags CFunctions
