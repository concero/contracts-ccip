type envString = string | undefined;
export type CLFSecrets = {
  WALLET_PRIVATE_KEY: envString;
  INFURA_API_KEY: envString;
};

const secrets: CLFSecrets = {
  WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
};

export default secrets;
