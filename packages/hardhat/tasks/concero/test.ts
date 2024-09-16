import { task } from "hardhat/config";
import CNetworks from "../../constants/CNetworks";
import { getFallbackClients } from "../../utils/getViemClients";

function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return hash.digest("hex");
}

task("test-script", "A test script").setAction(async taskArgs => {
  console.log(hre.network.name);
  const chain = CNetworks[hre.network.name];

  const { publicClient } = getFallbackClients(chain);
  await publicClient.simulateContract();
  console.log("Running test-script");
  // const [conceroProxy, conceroProxyAlias] = getEnvAddress("infraProxy", chain.name);
  // console.log(conceroProxy, conceroProxyAlias);

  // await deployProxyAdmin(hre, ProxyType.parentPool);
  // await deployTransparentProxy(hre, ProxyType.parentPool);
  // await upgradeProxyImplementation(hre, ProxyType.parentPool, false);
});

export default {};
