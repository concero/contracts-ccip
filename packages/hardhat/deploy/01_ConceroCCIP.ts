import { ConceroCCIP } from "../artifacts/contracts/ConceroCCIP.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployConceroCCIP: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI } = process.env;

  console.log("LINK_MUMBAI", LINK_MUMBAI);
  console.log("CL_CCIP_ROUTER_MUMBAI", CL_CCIP_ROUTER_MUMBAI);

  await deploy("ConceroCCIP", {
    from: deployer,
    log: true,
    args: [LINK_MUMBAI, CL_CCIP_ROUTER_MUMBAI],
    autoMine: true,
  });

  const conceroBridge = await hre.ethers.getContract<ConceroCCIP>("ConceroCCIP", deployer);
};

export default deployConceroCCIP;
deployConceroCCIP.tags = ["ConceroCCIP"];
// yarn deploy --tags CFunctions
