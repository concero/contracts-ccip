import fs from "fs";
import { buildScript } from "../tasks/script/build";
import log from "../utils/log";
import path from "path";

type envString = string | undefined;
export type CLFSecrets = {
  WALLET_PRIVATE_KEY: envString;
  INFURA_API_KEY: envString;
  ALCHEMY_API_KEY: envString;
  SRC_JS: string;
  DST_JS: string;
};
const jsPath = "./tasks/CLFScripts";
const secrets: CLFSecrets = {
  WALLET_PRIVATE_KEY: process.env.MESSENGER_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
  ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
  SRC_JS: getJS(jsPath, "SRC"),
  DST_JS: getJS(jsPath, "DST"),
};

export default secrets;

function getJS(jsPath: string, type: string): string {
  const source = path.join(jsPath, "src", `${type}.js`);
  const dist = path.join(jsPath, "dist", `${type}.min.js`);

  if (!fs.existsSync(dist)) {
    log(`File not found: ${dist}, building...`, "getJS");
    buildScript(source);
  }

  return fs.readFileSync(dist, "utf8");
}
