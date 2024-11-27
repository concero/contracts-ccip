import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts, log } from "../../../utils";
import { conceroNetworks } from "../../../constants";
import { setParentPoolJsHashes } from "./setParentPoolVariables";

task("update-parent-pool-js-hashes", "").setAction(async taskArgs => {
  const hre: HardhatRuntimeEnvironment = require("hardhat");
  compileContracts({ quiet: true });
  const chain = conceroNetworks[hre.network.name];
  const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  await setParentPoolJsHashes(chain, ParentPoolAbi);

  log(`[Set] ParentPool.js hashes`, "update-parent-pool-js-hashes", chain.name);
});

export default {};
