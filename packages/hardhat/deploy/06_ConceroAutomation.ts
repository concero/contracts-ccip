import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import getHashSum from "../utils/getHashSum";
import path from "path";
import fs from "fs";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  functionsDonId?: number;
  functionsSubIds?: number;
  slotId?: number; //Need to create this
  donHostedSecretsVersion?: string;
  hashSum?: string; //Need to create this
  etherHashSum?: string;
  functionsRouter?: string;
  parentProxyAddress?: string;
  owner?: string;
}

const deployConceroAutomation: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { functionsRouter, functionsDonId, functionsSubIds, donHostedSecretsVersion } = chains[name];

  const jsPath = "./tasks/CLFScripts";

  function getJS(jsPath: string, type: string): string {
    const dist = path.join(jsPath, "dist", `${type}.min.js`);

    return fs.readFileSync(dist, "utf8");
  }

  const defaultArgs = {
    functionsDonId: functionsDonId,
    functionsSubIds: functionsSubIds,
    functionsSlotId: constructorArgs.slotId || 0, //Need to create this
    donHostedSecretsVersion: donHostedSecretsVersion,
    hashSum: getHashSum(getJS(jsPath, "getTotalBalance")), //Need to create this
    etherHashSum: getHashSum(
      await (
        await fetch("https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js")
      ).text(),
    ), //Need to create this
    functionsRouter: functionsRouter,
    parentProxyAddress: getEnvVar(`CONCEROAUTOMATION_${networkEnvKeys[name]}`),
    owner: deployer,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ConceroAutomation...");
  const deployConceroAutomation = (await deploy("ConceroAutomation", {
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
    log(`ConceroAutomation deployed to ${name} to: ${deployConceroAutomation.address}`, "deployConceroAutomation");
    updateEnvVariable(
      `CONCEROAUTOMATION_${networkEnvKeys[name]}`,
      deployConceroAutomation.address,
      "../../../.env.deployments",
    );
  }
};

export default deployConceroAutomation;
deployConceroAutomation.tags = ["ConceroAutomation"];
