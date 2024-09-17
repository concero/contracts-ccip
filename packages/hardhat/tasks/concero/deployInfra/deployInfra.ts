import { task, types } from "hardhat/config";
import CNetworks, { conceroChains, networkTypes, ProxyEnum } from "../../../constants";
import { setConceroProxyDstContracts, setContractVariables } from "./setContractVariables";
import { CNetwork } from "../../../types/CNetwork";
import uploadDonSecrets from "../../CLF/donSecrets/upload";
import deployConcero from "../../../deploy/04_ConceroBridge";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";
import deployConceroOrchestrator from "../../../deploy/05_ConceroOrchestrator";
import addCLFConsumer from "../../CLF/subscriptions/add";
import { compileContracts, getEnvAddress } from "../../../utils";
import deployProxyAdmin from "../../../deploy/10_ConceroProxyAdmin";
import deployTransparentProxy from "../../../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
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
    const { live, name } = hre.network;
    const networkType = CNetworks[name].type;
    let deployableChains: CNetwork[] = [];
    if (live) deployableChains = [CNetworks[hre.network.name]];

    let liveChains: CNetwork[] = [];
    if (networkType == networkTypes.mainnet) {
      liveChains = conceroChains.mainnet.infra;
    } else {
      liveChains = conceroChains.testnet.infra;
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
  const { hre, deployableChains, deployProxy, deployImplementation, setVars, uploadSecrets, slotId } = params;
  const { name } = hre.network;
  // const { deployer, proxyDeployer } = await hre.getNamedAccounts();

  if (deployProxy) {
    // await ensureWalletBalance(proxyDeployer, deployerTargetBalances, cNetworks[name]);
    await deployProxyAdmin(hre, ProxyEnum.infraProxy);
    await deployTransparentProxy(hre, ProxyEnum.infraProxy);

    const [proxyAddress] = getEnvAddress(ProxyEnum.infraProxy, name);
    const { functionsSubIds } = CNetworks[name];
    await addCLFConsumer(CNetworks[name], [proxyAddress], functionsSubIds[0]);
  }

  // await ensureWalletBalance(deployer, deployerTargetBalances, cNetworks[name]);

  if (deployImplementation) {
    await deployConceroDexSwap(hre);
    await deployConcero(hre, { slotId });
    await deployConceroOrchestrator(hre);
    await upgradeProxyImplementation(hre, ProxyEnum.infraProxy, false);
  }

  if (setVars) {
    if (uploadSecrets) {
      await uploadDonSecrets(deployableChains, slotId, 4320);
    }
    await setContractVariables(deployableChains, slotId, uploadSecrets);
    await setConceroProxyDstContracts(deployableChains);
  }
}

export default {};
