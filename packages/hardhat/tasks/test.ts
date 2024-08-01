import { task } from "hardhat/config";
import deployProxyAdmin from "../deploy/10_ProxyAdmin";

import deployTransparentProxy, { ProxyType } from "../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "./concero/upgradeProxyImplementation";

function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return hash.digest("hex");
}

task("test-script", "A test script").setAction(async taskArgs => {
  await deployProxyAdmin(hre, ProxyType.infra);
  await deployTransparentProxy(hre, ProxyType.infra);
  await upgradeProxyImplementation(hre, ProxyType.infra, false);
});

export default {};
