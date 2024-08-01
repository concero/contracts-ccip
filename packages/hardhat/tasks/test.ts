import { task } from "hardhat/config";

function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return hash.digest("hex");
}

task("test-script", "A test script").setAction(async taskArgs => {
  console.log("Running test-script");
  // await deployProxyAdmin(hre, ProxyType.parentPool);
  // await deployTransparentProxy(hre, ProxyType.parentPool);
  // await upgradeProxyImplementation(hre, ProxyType.parentPool, false);
});

export default {};
