import { CNetwork } from "../types/CNetwork";
import { execSync } from "child_process";
import { reloadDotEnv } from "../utils/dotenvConfig";

export async function deployContract(chains: CNetwork[]) {
  for (const chain of chains) {
    execSync(`bunx hardhat deploy --network ${chain.name} --tags Concero`, { stdio: "inherit" });
  }
  reloadDotEnv();
}
