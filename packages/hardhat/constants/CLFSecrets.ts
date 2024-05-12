type envString = string | undefined;
export type CLFSecrets = {
  WALLET_PRIVATE_KEY: envString;
  INFURA_API_KEY: envString;
  ALCHEMY_API_KEY: envString;
};

const secrets: CLFSecrets = {
  WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
  ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
  // srcjs: fs.readFileSync("./tasks/CLFScripts/dist/SRCfn.min.js", "utf8"),
  // dstjs: fs.readFileSync("./tasks/CLFScripts/dist/DSTfn.min.js", "utf8"),
};

export default secrets;
