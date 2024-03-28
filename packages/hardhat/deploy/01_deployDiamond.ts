/* global ethers */

/* eslint prefer-const: "off" */
import { CDiamond } from "../artifacts/contracts/CDiamond.sol";
import { DiamondCutFacet } from "../artifacts/contracts/facets/DiamondCutFacet.sol";
import { ethers } from "hardhat";
// import { getSelectors, FacetCutAction } from "./libraries/diamond";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployDiamond: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const accounts = await ethers.getSigners();
  const contractOwner = process.env.WALLET_ADDRESS;

  // deploy DiamondCutFacet
  await deploy("DiamondCutFacet", {
    from: deployer,
    log: true,
    autoMine: true,
  });

  const diamondCutFacet = await hre.ethers.getContract<DiamondCutFacet>("DiamondCutFacet", deployer);
  console.log("DiamondCutFacet deployed:", await diamondCutFacet.getAddress());

  // deploy Diamond
  await deploy("CDiamond", {
    from: deployer,
    args: [contractOwner, await diamondCutFacet.getAddress()],
    log: true,
    autoMine: true,
  });

  const diamond = await hre.ethers.getContract<CDiamond>("CDiamond", deployer);
  console.log("Diamond deployed:", await diamond.getAddress());

  //   const Diamond = await ethers.getContractFactory("Diamond");
  //   const diamond = await Diamond.deploy(contractOwner.getAddress(), diamondCutFacet.getAddress());
  //   console.log("Diamond deployed:", diamond.getAddress());
  //
  //   // deploy DiamondInit
  //   // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
  //   // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
  //   const DiamondInit = await ethers.getContractFactory("DiamondInit");
  //   const diamondInit = await DiamondInit.deploy();
  //
  //   console.log("DiamondInit deployed:", diamondInit.getAddress());
  //
  //   // deploy facets
  //   console.log("");
  //   console.log("Deploying facets");
  //   const FacetNames = ["DiamondLoupeFacet", "OwnershipFacet"];
  //   const cut = [];
  //   for (const FacetName of FacetNames) {
  //     const Facet = await ethers.getContractFactory(FacetName);
  //     const facet = await Facet.deploy();
  //     console.log(`${FacetName} deployed: ${facet.getAddress()}`);
  //     cut.push({
  //       facetAddress: facet.address,
  //       action: FacetCutAction.Add,
  //       functionSelectors: getSelectors(facet),
  //     });
  //   }
  //
  //   // upgrade diamond with facets
  //   console.log("");
  //   console.log("Diamond Cut:", cut);
  //   const diamondCut = await ethers.getContractAt("IDiamondCut", diamond.getAddress());
  //   let tx;
  //   let receipt;
  //   // call to init function
  //   let functionCall = diamondInit.interface.encodeFunctionData("init");
  //   tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
  //   console.log("Diamond cut tx: ", tx.hash);
  //   receipt = await tx.wait();
  //   if (!receipt.status) {
  //     throw Error(`Diamond upgrade failed: ${tx.hash}`);
  //   }
  //   console.log("Completed diamond cut");
  //   return diamond.address;
  // }

  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  // if (require.main === module) {
  //   deployDiamond()
  //     .then(() => process.exit(0))
  //     .catch(error => {
  //       console.error(error);
  //       process.exit(1);
  //     });
};

export default deployDiamond;
