import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

 When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
 should have sufficient balance to pay for the gas fees for contract creation.

 You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
 with a random private key in the .env file (then used on hardhat.config.ts)
 You can run the `yarn account` command to check your balance in every network.
 */
const deployCFunctions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { CL_FUNCTIONS_ROUTER_MUMBAI, CL_FUNCTIONS_DON_ID_MUMBAI } = process.env;

  await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [CL_FUNCTIONS_ROUTER_MUMBAI, CL_FUNCTIONS_DON_ID_MUMBAI],
    autoMine: true,
  });

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
};

export default deployCFunctions;
deployCFunctions.tags = ["CFunctions"];
// yarn deploy --tags CFunctions
