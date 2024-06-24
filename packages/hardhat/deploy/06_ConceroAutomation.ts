import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  functionsDonId?: number;
  functionsSubIds?: number;
  functionsSlotId?: number; //Need to create this
  donHostedSecretsVersion?: string;
  hashSum?: string; //Need to create this
  etherHashSum?: string;
  functionsRouter?: string;
  parentProxyAddress?: string;
  owner?: string;
}

const deployParentPool: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const {
    functionsRouter,
    functionsDonId,
    functionsSubIds,
    functionsSlotId,
    donHostedSecretsVersion,
  } = chains[name];

  const defaultArgs = {
    functionsDonId: functionsDonId,
    functionsSubIds: functionsSubIds,
    functionsSlotId: functionsSlotId, //Need to create this
    donHostedSecretsVersion: donHostedSecretsVersion,
    hashSum: hashSum, //Need to create this
    etherHashSum: etherHashSum, //Need to create this
    functionsRouter: functionsRouter,
    parentProxyAddress: getEnvVar(`PARENTPROXY_${networkEnvKeys[name]}`),
    owner: deployer,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ParentPool...");
  const deployParentPool = (await deploy("ParentPool", {
    from: deployer,
    args: [
      args.functionsDonId,
      args.functionsSubIds,
      args.functionsSlotId,
      args.donHostedSecretsVersion,
      args.hashSum,
      args.etherHashSum,
      args.functionsRouter,
      args.parentProxyAddress,
      args.owner,
    ],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ParentPool deployed to ${name} to: ${deployParentPool.address}`, "deployParentPool");
    updateEnvVariable(`PARENTPOOL_${networkEnvKeys[name]}`, deployParentPool.address, "../../../.env.deployments");
  }
};

export default deployParentPool;
deployParentPool.tags = ["ParentPool"];
