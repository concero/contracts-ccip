import { task, types } from "hardhat/config";
import chains from "../../../constants/CNetworks";
import CNetworks, { networkEnvKeys, NetworkType } from "../../../constants/CNetworks";
import { setConceroProxyDstContracts } from "./setContractVariables";
import { CNetwork } from "../../../types/CNetwork";
import uploadDonSecrets from "../../donSecrets/upload";
import deployConcero from "../../../deploy/04_ConceroBridge";
import { conceroChains } from "../liveChains";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";
import deployConceroOrchestrator from "../../../deploy/05_ConceroOrchestrator";
import addCLFConsumer from "../../sub/add";
import { getEnvVar } from "../../../utils/getEnvVar";
import deployProxyAdmin from "../../../deploy/10_ConceroProxyAdmin";
import deployTransparentProxy, { ProxyType } from "../../../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import { compileContracts } from "../../../utils/compileContracts";
import { deployerTargetBalances, ensureWalletBalance } from "../../ensureBalances/ensureBalances";
import { DeployInfraParams } from "./types";

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("deployimplementation", "Deploy the implementation")
  .addFlag("setvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Upload DON-hosted secrets")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .setAction(async taskArgs => {
    compileContracts({ quiet: true });

    const hre = require("hardhat");
    const { live, tags } = hre.network;

    let deployableChains: CNetwork[] = [];
    let networkType: NetworkType;
    if (live) deployableChains = [CNetworks[hre.network.name]];

    let liveChains: CNetwork[] = [];
    if (tags[NetworkType.mainnet]) {
      liveChains = conceroChains.mainnet.infra;
      networkType = NetworkType.mainnet;
    } else {
      liveChains = conceroChains.testnet.infra;
      networkType = NetworkType.testnet;
    }

    await deployInfra({
      hre,
      deployableChains,
      liveChains,
      networkType,
      deployProxy: taskArgs.deployproxy,
      deployImplementation: taskArgs.deployimplementation,
      setVars: taskArgs.setvars,
      uploadSecrets: taskArgs.uploadsecrets,
      slotId: parseInt(taskArgs.slotid),
    });
  });

async function deployInfra(params: DeployInfraParams) {
  const { hre, deployableChains, networkType, deployProxy, deployImplementation, setVars, uploadSecrets, slotId } =
    params;
  const { name } = hre.network;
  const { deployer } = await hre.getNamedAccounts();
  await ensureWalletBalance(deployer, deployerTargetBalances, CNetworks[name]);

  if (deployProxy) {
    await deployProxyAdmin(hre, ProxyType.infra);
    await deployTransparentProxy(hre, ProxyType.infra);

    const proxyAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`);
    const { functionsSubIds } = chains[name];
    await addCLFConsumer(chains[name], [proxyAddress], functionsSubIds[0]);
  }

  if (deployImplementation) {
    await deployConceroDexSwap(hre);
    await deployConcero(hre, { slotId });
    await deployConceroOrchestrator(hre);
    await upgradeProxyImplementation(hre, ProxyType.infra, false);
  }

  if (setVars) {
    if (uploadSecrets) {
      await uploadDonSecrets(deployableChains, slotId, 4320);
    }
    // await setContractVariables(liveChains, deployableChains, slotId, uploadSecrets);
    await setConceroProxyDstContracts(deployableChains);
  }
}

export default {};
