import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts, log } from "../../../utils";
import { conceroNetworks } from "../../../constants";
import { setJsHashes } from "./setContractVariables";

task("update-infra-js-hashes", "").setAction(async taskArgs => {
  const hre: HardhatRuntimeEnvironment = require("hardhat");
  compileContracts({ quiet: true });
  const chain = conceroNetworks[hre.network.name];
  const { abi } = await import("../../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json");

  await setJsHashes(chain, abi);

  log(`Updated JS hashes for ${chain.name} Infra contracts`, "update-infra-js-hashes");
});

export default {};
