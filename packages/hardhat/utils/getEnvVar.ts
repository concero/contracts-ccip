import { type env } from "../types/env";
import process from "process";
import { shorten } from "./formatting";
import { networkEnvKeys } from "../constants/CNetworks";
import { deploymentPrefixes, DeploymentPrefixes } from "../constants/deploymentVariables";
import { CNetworkNames } from "../types/CNetwork";
import { Address } from "viem";

export function getEnvVar(key: keyof env): string {
  const value = process.env[key];
  if (value === undefined) throw new Error(`Missing required environment variable ${key}`);
  if (value === "") throw new Error(`${key} must not be empty`);
  return value;
}

export function getEnvAddress(
  prefix: keyof DeploymentPrefixes,
  networkName?: CNetworkNames | string,
): [Address, string] {
  const searchKey = networkName
    ? `${deploymentPrefixes[prefix]}_${networkEnvKeys[networkName]}`
    : deploymentPrefixes[prefix];

  const value = getEnvVar(searchKey) as Address;
  const friendlyName = `${prefix}(${shorten(value)})`;

  return [value, friendlyName];
}
