import { type Address } from "viem";

export function shorten(address: Address) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function formatGas(gasAmountWei: bigint) {
  // splits gas number with commas like so: 1,000,000
  return gasAmountWei.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}
