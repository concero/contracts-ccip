import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";

const deployConceroCCIP: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  // if (!CNetworks[hre.network.name]) throw new Error(`Chain ${hre.network.name} not supported`);
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, conceroChainIndex } =
    chains[name];

  const donHostedSecretsVersion = process.env[`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`]; // gets up-to-date env variable
  const chainIndex = "0";
  const { address: contractAddress } = await deploy("ConceroCCIP", {
    from: deployer,
    log: true,
    args: [
      functionsRouter,
      donHostedSecretsVersion,
      functionsDonId,
      functionsSubIds[0],
      chainSelector,
      chainIndex,
      linkToken,
      ccipRouter,
    ],
    autoMine: true,
  });

  // const conceroCCIP = await hre.ethers.getContract<ConceroCCIP>("ConceroCCIP", deployer);

  // await conceroCCIP.setAllowSourceChain(oppositeChainSelector, true);
  // await conceroCCIP.setAllowDestinationChain(oppositeChainSelector, true);

  // exec(`npx hardhat verify --network polygonMumbai ${contractAddress} ${linkTokenAddress} ${router}`, (error, stdout, stderr) => {
  //   console.log(stdout);
  //   console.log(stderr);
  //   console.log(error);
  // });
};

deployConceroCCIP.tags = ["ConceroCCIP"];
export default deployConceroCCIP;
