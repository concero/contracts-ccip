import { decodeEventLog, encodeEventTopics, getAbiItem } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";

export async function findEventLog(
  eventName: string,
  filterArgs: Record<string, any>,
  abi: any,
  startBlock: bigint,
  endBlock: bigint,
  address: string,
  publicClient: PublicClient,
) {
  const eventAbi = getAbiItem({ abi, name: eventName });
  const topics = encodeEventTopics({
    abi: [eventAbi],
    eventName,
    args: filterArgs,
  });

  const logs = await publicClient.getLogs({
    fromBlock: startBlock,
    toBlock: endBlock,
    address,
    topics,
  });

  for (const log of logs) {
    try {
      const event = decodeEventLog({
        abi: [eventAbi],
        data: log.data,
        topics: log.topics,
      });

      const allArgsMatch = Object.keys(filterArgs).every(
        key => event.args[key]?.toString() === filterArgs[key]?.toString(),
      );

      if (allArgsMatch) {
        return event;
      }
    } catch (err) {}
  }

  throw new Error(`${eventName} event not found in transaction logs.`);
}
