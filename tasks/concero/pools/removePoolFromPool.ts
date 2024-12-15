import { compileContracts, getClients, getEnvAddress, getEnvVar } from "../../../utils";
import { conceroNetworks, networkEnvKeys, ProxyEnum } from "../../../constants";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("remove-pool-from-pool", "Deploy the CCIP infrastructure")
  .addParam("pooltoremovechain", "Deploy the proxy")
  .setAction(async taskArgs => {
    compileContracts({ quiet: true });

    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { live, name } = hre.network;
    const poolToRemoveNetworkName = taskArgs.pooltoremovechain;
    const [poolToRemoveFromAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
    const cNetwork = conceroNetworks[name];
    const poolToRemoveChainSelector = getEnvVar(`CL_CCIP_CHAIN_SELECTOR_${networkEnvKeys[poolToRemoveNetworkName]}`);
    const { walletClient, publicClient, account } = getClients(cNetwork.viemChain);
    const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

    const hash = await walletClient.writeContract({
      account,
      address: poolToRemoveFromAddress,
      functionName: "removePools",
      args: [poolToRemoveChainSelector],
      abi: ParentPoolAbi,
      chain: cNetwork.viemChain,
    });

    const receipt = await publicClient.waitForTransactionReceipt({
      hash,
    });

    if (receipt.status === "success") {
      console.log(`Pool removed successfully ${hash}`);
    } else {
      console.log(`Pool removal failed ${hash}`);
    }
  });

export default {};
