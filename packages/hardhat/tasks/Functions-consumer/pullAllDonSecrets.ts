import { task } from "hardhat/config";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import { execSync } from "child_process";

// run with:  bunx hardhat functions-pull-all-don-secrets
task("functions-pull-all-don-secrets", "Fetches and updates secrets from all networks defined in networkEnvKeys").setAction(async taskArgs => {
  // console.log(hre.config.networks);
  for (const networkKey of Object.keys(networkEnvKeys)) {
    try {
      if (!chains[networkKey]) {
        console.error(`No chains found for ${networkKey}. Skipping...`);
        continue;
      }
      const command = `bunx hardhat functions-list-don-secrets --network ${networkKey}`;
      const output = execSync(command, { stdio: "inherit" }); // This will show output in real-time
      if (output) console.log(output.toString());
    } catch (error) {
      console.error(`Failed to run task for ${networkKey}:`, error);
    }
  }
});

export default {};
