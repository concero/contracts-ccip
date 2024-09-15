import { getEnvVar } from "../utils/getEnvVar";

type envString = string | undefined;
export type CLFSecrets = {
  MESSENGER_0_PRIVATE_KEY: envString;
  MESSENGER_1_PRIVATE_KEY: envString;
  MESSENGER_2_PRIVATE_KEY: envString;
  POOL_MESSENGER_0_PRIVATE_KEY: envString;
  INFURA_API_KEY: envString;
  ALCHEMY_API_KEY: envString;
};

const secrets: CLFSecrets = {
  MESSENGER_0_PRIVATE_KEY: getEnvVar("MESSENGER_0_PRIVATE_KEY"),
  MESSENGER_1_PRIVATE_KEY: getEnvVar("MESSENGER_1_PRIVATE_KEY"),
  MESSENGER_2_PRIVATE_KEY: getEnvVar("MESSENGER_2_PRIVATE_KEY"),
  POOL_MESSENGER_0_PRIVATE_KEY: getEnvVar("POOL_MESSENGER_0_PRIVATE_KEY"),
  INFURA_API_KEY: getEnvVar("INFURA_API_KEY"),
  ALCHEMY_API_KEY: getEnvVar("ALCHEMY_API_KEY"),
};

export default secrets;
