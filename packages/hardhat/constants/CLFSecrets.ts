import fs from "fs";

type envString = string | undefined;
export type CLFSecrets = {
  WALLET_PRIVATE_KEY: envString;
  INFURA_API_KEY: envString;
  ALCHEMY_API_KEY: envString;
  SRC_JS: string;
  DST_JS: string;
};

const secrets: CLFSecrets = {
  WALLET_PRIVATE_KEY: process.env.MESSENGER_WALLET_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
  ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
  SRC_JS: fs.readFileSync("./tasks/CLFScripts/dist/SRCfn.min.js", "utf8"),
  DST_JS: fs.readFileSync("./tasks/CLFScripts/dist/DSTfn.min.js", "utf8"),
};

export default secrets;
