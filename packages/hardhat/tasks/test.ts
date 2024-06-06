import { task } from "hardhat/config";
import secrets from "../constants/CLFSecrets";

function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return hash.digest("hex");
}

task("test-script", "A test script").setAction(async taskArgs => {
  const hashsum = getHashSum(secrets.SRC_JS);
  console.log(hashsum);
});

export default {};
