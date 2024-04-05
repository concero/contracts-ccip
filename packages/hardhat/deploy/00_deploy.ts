import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
import { ConceroCCIP } from "../artifacts/contracts/ConceroCCIP.sol";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const ethAddress = "0x0000000000000000000000000000000000000000";
const usdcAddress = "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318";
const ROUTER_ADDRESS = "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59";
const LINK_ADDRESS = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
const USDC_SEPOLIA = "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d";
const USDC_MAINNET = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
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

  const fujiLinkAddress = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846";
  const fujiCcipRouterAddress = "0xF694E193200268f9a4868e4Aa017A0118C9a8177";
  const fujiChainSelector = "14767482510784806043";
  const fujiDonId = "0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000";
  const fujiFunctionRouter = "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0";
  const mumbaiLinkAddress = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";
  const mumbaiCcipRouterAddress = "0x1035CabC275068e0F4b745A29CEDf38E13aF41b1";
  const mumbaiChainSelector = "12532609583862916517";
  const mumbaiDonId = "0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000";
  const mumbaiFunctionRouter = "0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C";

  // await deploy("ConceroBridge", {
  //   from: deployer,
  //   args: [mumbaiLinkAddress, mumbaiCcipRouterAddress, mumbaiFunctionRouter, mumbaiDonId],
  //   log: true,
  //   autoMine: true,
  // });
  // const conceroCCIP = await hre.ethers.getContract<ConceroCCIP>("ConceroBridge", deployer);

  await deploy("CFunctions", {
    from: deployer,
    log: true,
    args: [mumbaiFunctionRouter, mumbaiDonId],
    autoMine: true,
  });

  const cFunctions = await hre.ethers.getContract<CFunctions>("CFunctions", deployer);
  // console.log("Concero CCIP Address: ", conceroCCIP.address);

  // const usdcBalance = await liquidityPool.balanceOf(usdcAddress, WALLET_ADDRESS);
  // console.log("USDC Balance: ", usdcBalance.toString());

  // const walletBalance = await testUSDC.balanceOf(WALLET_ADDRESS);
  // if (walletBalance < ethers.parseEther("1000"))
  // await testUSDC.mint(WALLET_ADDRESS, ethers.parseEther("1000"));

  // const liquidityPool = await hre.ethers.getContract<LiquidityPool>("LiquidityPool", deployer);
};

export default deployYourContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourContract.tags = ["YourContract"];
