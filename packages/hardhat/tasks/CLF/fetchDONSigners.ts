import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { decodeEventLog, getAbiItem } from "viem";
import { err, getFallbackClients, log } from "../../utils";
import chains from "../../constants/cNetworks";
import functionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";
import functionsCoordinatorAbi from "@chainlink/contracts/abi/v0.8/FunctionsCoordinator.json";

//todo: base throws max block range 5000 error. find a better RPC to fetch signers for base.
const mainnetNetworks = [
  // chains.mainnet, // no mainnet & opt object in conceroNetworks yet
  chains.base,
  chains.arbitrum,
  // chains.optimism,
  chains.avalanche,
  chains.polygon,
];

const testnetNetworks = [
  chains.sepolia,
  chains.baseSepolia,
  chains.arbitrumSepolia,
  chains.optimismSepolia,
  chains.avalancheFuji,
  chains.polygonAmoy,
];

const clfCoordinatorCreationBlock = {
  sepolia: 6324301n,
  optimismSepolia: 13984884n,
  baseSepolia: 6597139n,
  arbitrumSepolia: 6597139n,
  avalancheFuji: 34877338n,
  base: 16624931n,
  arbitrum: 228424668n,
  polygon: 58905676n,
  avalanche: 48089579n,
};

const MAX_BLOCK_RANGE = 1000000n; // Adjust according to the provider's limits

async function fetchLogsInChunks(publicClient, parameters, maxBlockRange) {
  const fromBlock = parameters.fromBlock;
  const toBlock = parameters.toBlock;

  let logs = [];
  let currentFromBlock = fromBlock;
  const latestBlock = toBlock;

  while (currentFromBlock <= latestBlock) {
    // console.log(`Fetching logs from block ${currentFromBlock} to block ${latestBlock}`);
    const currentToBlock = currentFromBlock + maxBlockRange - 1n;
    const actualToBlock = currentToBlock > latestBlock ? latestBlock : currentToBlock;

    const chunkLogs = await publicClient.getLogs({
      ...parameters,
      fromBlock: currentFromBlock,
      toBlock: actualToBlock,
    });

    logs = logs.concat(chunkLogs);

    currentFromBlock = actualToBlock + 1n;
  }

  return logs;
}

export async function fetchDONSigners(isTestnet: boolean) {
  const watchedChains = isTestnet ? testnetNetworks : mainnetNetworks;

  for (const chain of watchedChains) {
    const { functionsRouter, functionsDonId, functionsCoordinator, viemChain, name } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);

    try {
      const { result: fetchedCLFCoordinatorAddress } = await publicClient.simulateContract({
        address: functionsRouter,
        abi: functionsRouterAbi,
        functionName: "getContractById",
        args: [functionsDonId],
        chain: viemChain,
        account,
      });

      // console.log(`[${name}] Fetched CLFCoordinator address: ${fetchedCLFCoordinatorAddress}`);

      if (fetchedCLFCoordinatorAddress && fetchedCLFCoordinatorAddress !== functionsCoordinator) {
        err(
          `Fetched CLFCoordinator address doesn't match env CLFCoordinator. Fetched: ${fetchedCLFCoordinatorAddress} Current: ${functionsCoordinator}`,
          "fetchDONSigners",
          name,
        );
        continue;
      } else if (!fetchedCLFCoordinatorAddress) {
        err(`Couldn't fetch CLFCoordinator address from CLFRouter`, "fetchDONSigners", name);
        continue;
      }

      const configSetEventAbi = getAbiItem({ abi: functionsCoordinatorAbi, name: "ConfigSet" });
      const latestBlockNumber = await publicClient.getBlockNumber();
      const fromBlock = clfCoordinatorCreationBlock[name];

      log(
        `[${name}] Fetching ConfigSet logs for contract ${fetchedCLFCoordinatorAddress}. This may take a while...`,
        "fetchDONSigners",
        name,
      );
      const logs = await fetchLogsInChunks(
        publicClient,
        {
          address: fetchedCLFCoordinatorAddress,
          event: configSetEventAbi,
          fromBlock: fromBlock,
          toBlock: latestBlockNumber,
        },
        MAX_BLOCK_RANGE,
      );

      if (!logs || logs.length === 0) {
        err(`No ConfigSet logs found for contract ${fetchedCLFCoordinatorAddress}`, "fetchDONSigners", name);
        continue;
      }

      const latestLog = logs[logs.length - 1];

      const decodedEvent = decodeEventLog({
        abi: [configSetEventAbi],
        data: latestLog.data,
        topics: latestLog.topics,
      });

      const signers = decodedEvent.args.signers;

      log(`[${name}] DON Signers:`, "fetchDONSigners", name);
      console.table(signers);
    } catch (error) {
      err(`${error.message}`, "fetchDONSigners", name);
    }
  }
}

task("fetch-don-signers", "Fetch DON signers")
  .addFlag("testnet", "Fetch signers from testnet networks")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    await fetchDONSigners(taskArgs.testnet);
  });

export default fetchDONSigners;
