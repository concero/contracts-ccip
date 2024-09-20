import { compileContracts } from "./compileContracts";
import configureDotEnv from "./dotenvConfig";
import { formatGas, shorten } from "./formatting";
import {
  getEthersSignerAndProvider,
  getEthersV5FallbackSignerAndProvider,
  getEthersV6FallbackSignerAndProvider,
  getEthersV6SignerAndProvider,
} from "./getEthersSignerAndProvider";
import getHashSum from "./getHashSum";
import { getClients, getFallbackClients } from "./getViemClients";
import { err, log, warn } from "./log";
import { getEnvAddress, getEnvVar } from "./getEnvVar";
import { updateEnvAddress, updateEnvVariable } from "./updateEnvVariable";

export {
  compileContracts,
  configureDotEnv,
  shorten,
  formatGas,
  getEnvVar,
  getEnvAddress,
  getEthersV5FallbackSignerAndProvider,
  getEthersSignerAndProvider,
  getEthersV6FallbackSignerAndProvider,
  getEthersV6SignerAndProvider,
  getHashSum,
  getClients,
  getFallbackClients,
  log,
  warn,
  err,
  updateEnvVariable,
  updateEnvAddress,
};
