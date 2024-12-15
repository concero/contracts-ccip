import { task, types } from "hardhat/config";
import { conceroChains, conceroNetworks, networkTypes, ProxyEnum } from "../../../constants";
import { setConceroProxyDstContracts, setContractVariables } from "./setContractVariables";
import { CNetwork } from "../../../types/CNetwork";
import uploadDonSecrets from "../../CLF/donSecrets/upload";
import deployConcero from "../../../deploy/ConceroBridge";
import deployConceroDexSwap from "../../../deploy/ConceroDexSwap";
import deployConceroOrchestrator from "../../../deploy/ConceroOrchestrator";
import addCLFConsumer from "../../CLF/subscriptions/add";
import { compileContracts, getEnvAddress, verifyVariables } from "../../../utils";
import deployProxyAdmin from "../../../deploy/ConceroProxyAdmin";
import deployTransparentProxy from "../../../deploy/TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import { DeployInfraParams } from "./types";
import { CLF_SECRETS_MAINNET_EXPIRATION, CLF_SECRETS_TESTNET_EXPIRATION } from "../../../constants/CLFSecrets";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("deployimplementation", "Deploy the implementation")
  .addFlag("setvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Upload DON-hosted secrets")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .setAction(async taskArgs => {
    compileContracts({ quiet: true });

    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { live, name } = hre.network;
    const networkType = conceroNetworks[name].type;
    let deployableChains: CNetwork[] = [];
    if (live) deployableChains = [conceroNetworks[hre.network.name]];

    let liveChains: CNetwork[] = [];
    if (networkType == networkTypes.mainnet) {
      liveChains = conceroChains.mainnet.infra;
      await verifyVariables();
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
  const isTestnet = deployableChains[0].type === "testnet";

  if (deployProxy) {
    await deployProxyAdmin(hre, ProxyEnum.infraProxy);
    await deployTransparentProxy(hre, ProxyEnum.infraProxy);
    const [proxyAddress] = getEnvAddress(ProxyEnum.infraProxy, name);
    const { functionsSubIds } = conceroNetworks[name];
    await addCLFConsumer(conceroNetworks[name], [proxyAddress], functionsSubIds[0]);
  }

  if (deployImplementation) {
    await deployConceroDexSwap(hre);
    await deployConcero(hre, { slotId });
    await deployConceroOrchestrator(hre);
    await upgradeProxyImplementation(hre, ProxyEnum.infraProxy, false);
  }

  if (uploadSecrets) {
    await uploadDonSecrets(
      deployableChains,
      slotId,
      isTestnet ? CLF_SECRETS_TESTNET_EXPIRATION : CLF_SECRETS_MAINNET_EXPIRATION,
    );
  }
  if (setVars) {
    await setContractVariables(deployableChains, slotId, uploadSecrets);
    await setConceroProxyDstContracts(deployableChains);
  }
}

export default {};
