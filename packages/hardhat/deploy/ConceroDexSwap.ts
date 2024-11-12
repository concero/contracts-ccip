import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import conceroNetworks, { networkEnvKeys } from "../constants/conceroNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";
import { messengers } from "../constants";

const deployConceroDexSwap: (hre: HardhatRuntimeEnvironment) => Promise<void> = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = conceroNetworks[name].type;

  const conceroProxyAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`);

  log("Deploying...", "DexSwap", name);

  const deployResult = (await deploy("DexSwap", {
    from: deployer,
    args: [conceroProxyAddress, messengers],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`Deployed at: ${deployResult.address}`, "DexSwap", name);
    updateEnvVariable(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`, deployResult.address, `deployments.${networkType}`);
  }
};

export default deployConceroDexSwap;
deployConceroDexSwap.tags = ["ConceroDexSwap"];
