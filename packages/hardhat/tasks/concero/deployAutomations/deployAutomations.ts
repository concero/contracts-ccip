import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroAutomation from "../../../deploy/06_ConceroAutomation";
import { setAutomationsVariables } from "./setAutomationsVariables";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import { compileContracts, getEnvVar, getFallbackClients } from "../../../utils";
import addCLFConsumer from "../../CLF/subscriptions/add";
import log from "../../../utils/log";
import abi from "@chainlink/contracts/abi/v0.8/AutomationRegistrar2_1.json";
import { erc20Abi } from "viem";

task("deploy-pool-clfcla", "Deploy the automations")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addFlag("skipsetvars", "Skip setting the variables")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addOptionalParam("forwarder", "Automations forwarder address", undefined, types.string)
  .setAction(async taskArgs => {
    compileContracts({ quiet: true });

    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name } = hre.network;
    const slotId = parseInt(taskArgs.slotid);
    const chain = CNetworks[name];
    const { viemChain } = chain;
    if (!taskArgs.skipdeploy) {
      await deployConceroAutomation(hre, { slotId });

      const automationContractAddress = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[name]}`);
      await addCLFConsumer(chain, [automationContractAddress], chain.functionsSubIds[0]);
    }
    if (!taskArgs.skipsetvars) await setAutomationsVariables(hre, slotId, taskArgs.forwarder);

    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const { deployer } = await hre.getNamedAccounts();

    const automationsRegistrar = getEnvVar("CLA_REGISTRAR_BASE_SEPOLIA");
    const automationContractAddress = getEnvVar("CONCERO_AUTOMATION_BASE_SEPOLIA");
    const linkToken = getEnvVar("LINK_BASE_SEPOLIA");

    // link allowance set
    const { request: setAllowanceReq } = await publicClient.simulateContract({
      address: linkToken,
      abi: erc20Abi,
      functionName: "approve",
      args: [automationsRegistrar, 100000000000000000n],
      chain: viemChain,
      account,
    });

    const setAllowanceHash = await walletClient.writeContract(setAllowanceReq);
    const { cumulativeGasUsed: setAllowanceGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setAllowanceHash,
    });

    log(`setAllowance txHash: ${setAllowanceHash} gasUsed: ${setAllowanceGasUsed}`, "deploy-automations");

    const { request: addToRegistryReq } = await publicClient.simulateContract({
      address: automationsRegistrar,
      abi,
      functionName: "registerUpkeep",
      account,
      args: [
        {
          name: automationContractAddress,
          encryptedEmail: "0x",
          upkeepContract: automationContractAddress,
          gasLimit: 500000n,
          adminAddress: deployer,
          triggerType: 0n,
          checkData: "0x",
          triggerConfig: "0x",
          offchainConfig: "0x",
          amount: 100000000000000000n,
        },
      ],
      chain: viemChain,
    });

    const addToRegistryHash = await walletClient.writeContract(addToRegistryReq);
    const { cumulativeGasUsed: addToRegistryGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: addToRegistryHash,
    });
    log(`addToRegistry txHash: ${addToRegistryHash} gasUsed: ${addToRegistryGasUsed}`, "deploy-automations");
  });

export default {};
