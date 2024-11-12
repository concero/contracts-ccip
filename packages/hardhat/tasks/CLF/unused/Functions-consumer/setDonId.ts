import { conceroNetworks } from "../../../../constants/conceroNetworks";
import { task } from "hardhat/config";

task(
  "clf-set-donid",
  "Updates the oracle address for a FunctionsConsumer consumer contract using the FunctionsOracle address from `network-config.js`",
)
  .addParam("contract", "Address of the consumer contract to update")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    const donId = conceroNetworks[name].functionsDonId;
    console.log(`Setting donId to ${donId} in Functions consumer contract ${taskArgs.contract} on ${name}`);
    const consumerContractFactory = await hre.ethers.getContractFactory("FunctionsConsumer");
    const consumerContract = await consumerContractFactory.attach(taskArgs.contract);

    const donIdBytes32 = hre.ethers.utils.formatBytes32String(donId);
    const updateTx = await consumerContract.setDonId(donIdBytes32);

    console.log(
      `\nWaiting ${conceroNetworks[name].confirmations} blocks for transaction ${updateTx.hash} to be confirmed...`,
    );
    await updateTx.wait(conceroNetworks[name].confirmations);

    console.log(`\nUpdated donId to ${donId} for Functions consumer contract ${taskArgs.contract} on ${name}`);
  });
export default {};
