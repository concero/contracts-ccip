import { task } from "hardhat/config";

import deployTransparentProxy, { ProxyType } from "../deploy/11_TransparentProxy";
import deployProxyAdmin from "../deploy/10_ProxyAdmin";
import { upgradeProxyImplementation } from "./concero/upgradeProxyImplementation";

function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return hash.digest("hex");
}

task("test-script", "A test script").setAction(async taskArgs => {
  await deployProxyAdmin(hre, ProxyType.parentPool);
  await deployTransparentProxy(hre, ProxyType.parentPool);
  await upgradeProxyImplementation(hre, ProxyType.parentPool, false);
});

export default {};
