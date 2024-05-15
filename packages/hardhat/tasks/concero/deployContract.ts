import { CNetwork } from "../../types/CNetwork";
import { execSync } from "child_process";
import { reloadDotEnv } from "../../utils/dotenvConfig";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import log from "../../utils/log";

export async function deployContract(chains: CNetwork[], hre: HardhatRuntimeEnvironment) {
  log(`Deploying infra to ${chains.map(c => c.name).join(", ")}`, "deploy-infra");
  for (const chain of chains) {
    execSync(`bunx hardhat deploy --network ${chain.name} --tags Concero`, { stdio: "inherit" });
  }
  reloadDotEnv();
}
