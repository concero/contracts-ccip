import { ConceroCCIP } from "../artifacts/contracts/ConceroCCIP.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployConceroCCIP: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const chainId = await hre.getChainId();

  const deploymentOptions = {
    80001: {
      linkTokenAddress: process.env.LINK_MUMBAI,
      router: process.env.CL_CCIP_ROUTER_MUMBAI,
      // chainSelector: 12532609583862916517n,
    },
    43113: {
      linkTokenAddress: process.env.LINK_FUJI,
      router: process.env.CL_CCIP_ROUTER_FUJI,
      // chainSelector: 14767482510784806043n,
    },
  };
  if (!deploymentOptions[chainId]) throw new Error(`ChainId ${chainId} not supported`);
  const { linkTokenAddress, router } = deploymentOptions[chainId];

  await deploy("ConceroCCIP", {
    from: deployer,
    log: true,
    args: [linkTokenAddress, router],
    autoMine: true,
  });

  const conceroBridge = await hre.ethers.getContract<ConceroCCIP>("ConceroCCIP", deployer);
};

export default deployConceroCCIP;
deployConceroCCIP.tags = ["ConceroCCIP"];
// yarn deploy --tags CFunctions
