import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { LiquidityPool } from "../artifacts/contracts/Pool.sol";
const ethAddress = "0x0000000000000000000000000000000000000000";
const usdcAddress = "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318";
const ROUTER_ADDRESS = "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59";
const LINK_ADDRESS = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
const USDC_SEPOLIA = '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d';
/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployYourContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { WALLET_ADDRESS } = process.env;

  // await deploy("CCIPFacet", { from: deployer, args: [], log: true, autoMine: true });
  // const ccipInternal = await hre.ethers.getContract<CCIPFacet>("CCIPFacet", deployer);

  // await deploy("TestUSDC", { from: deployer, args: [deployer], log: true, autoMine: true });
  // const testUSDC = await hre.ethers.getContract<TestUSDC>("TestUSDC", deployer);

  // await deploy("Sender", { from: deployer, args: [ROUTER_ADDRESS, LINK_ADDRESS], log: true, autoMine: true });
  // const sender = await hre.ethers.getContract<Sender>("Sender", deployer);

  // await deploy("FundMe", { from: deployer, args: [], log: true, autoMine: true });
  // const fundMe = await hre.ethers.getContract<FundMe>("FundMe", deployer);

  await deploy("LiquidityPool",
    {
      from: deployer,
      args: [ethAddress, usdcAddress],
      log: true,
      autoMine: true
    });
  const liquidityPool = await hre.ethers.getContract<LiquidityPool>("LiquidityPool", deployer);
  const usdcBalance = await liquidityPool.balanceOf(usdcAddress, WALLET_ADDRESS);
  console.log("USDC Balance: ", usdcBalance.toString());



  // const walletBalance = await testUSDC.balanceOf(WALLET_ADDRESS);
  // if (walletBalance < ethers.parseEther("1000"))
  // await testUSDC.mint(WALLET_ADDRESS, ethers.parseEther("1000"));

  // const liquidityPool = await hre.ethers.getContract<LiquidityPool>("LiquidityPool", deployer);
};

export default deployYourContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourContract.tags = ["YourContract"];
