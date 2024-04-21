import { task } from "hardhat/config";
import { baseSepolia, optimismSepolia } from "viem/chains";
import { setContractVariables } from "./setContractVariables";
import { subscriptionHealthcheck } from "./ensureConsumerAdded";
import { deployContract } from "./deployContract";

/* todo:
- Make sure secrets for chain are set
 */

const networks = {
  baseSepolia,
  optimismSepolia,
  // arbitrumSepolia
};

task("deploy-ccip-infrastructure", "Deploy the CCIP infrastructure")
  .addOptionalParam("deploy", "Deploy the contract to a specific network", "true")
  .setAction(async taskArgs => {
    if (taskArgs.deploy === "true") {
      if (hre.network.name !== "localhost") {
        await deployContract(hre.network.name, networks);
      } else {
        for (const name in networks) {
          await deployContract(name, networks);
        }
      }
    } else {
      console.log("Skipping deployment");
    }

    const contracts = {
      baseSepolia: process.env.CONCEROCCIP_BASE_SEPOLIA,
      optimismSepolia: process.env.CONCEROCCIP_OPTIMISM_SEPOLIA,
      // arbitrumSepolia: process.env.CONCEROCCIP_ARBITRUM_SEPOLIA,
    };

    for (const [networkName, contractAddress] of Object.entries(contracts)) {
      await subscriptionHealthcheck(contractAddress, networkName, networks);
    }
    await setContractVariables(networks);
  });
export default {};
