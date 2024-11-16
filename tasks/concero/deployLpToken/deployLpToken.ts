import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployLPToken from "../../../deploy/LPToken";

task("deploy-lp-token", "Deploy the lp token").setAction(async taskArgs => {
  const hre: HardhatRuntimeEnvironment = require("hardhat");

  await deployLPToken(hre);
});

export default {};
