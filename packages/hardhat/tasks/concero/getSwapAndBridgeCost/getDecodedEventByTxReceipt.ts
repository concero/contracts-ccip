import { Abi, decodeEventLog, TransactionReceipt } from "viem";

export async function getDecodedEventByTxReceipt(
  txReceipt: TransactionReceipt,
  abi: Abi,
  eventName: string,
  contractAddress?: string,
) {
  for (const log of txReceipt.logs) {
    if (contractAddress && log.address.toLowerCase() !== contractAddress.toLowerCase()) {
      continue;
    }
    try {
      const event = decodeEventLog({
        abi,
        data: log.data,
        topics: log.topics,
      });

      if (event.eventName === eventName) {
        return event;
      }
    } catch (err) {
      // Handle decoding errors silently
    }
  }

  throw new Error(`${eventName} event not found in transaction logs.`);
}
