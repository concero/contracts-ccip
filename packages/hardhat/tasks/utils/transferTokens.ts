import { ethers } from "ethers";
import { createPublicClient } from "viem";
import chains from "../../constants/CNetworks";
import { BigNumber } from "ethers-v5";
import { task } from "hardhat/config";
import { multicall } from "viem/actions";
import { getEthersV6FallbackSignerAndProvider } from "./getEthersSignerAndProvider";

// Configuration

const { url, name } = chains["optimismSepolia"];
const { signer, provider } = getEthersV6FallbackSignerAndProvider(name);
const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);
const targetAddress = "0x";

const tokenAddresses = ["0xE4aB69C077896252FAFBD49EFD26B5D171A32410"];

// Multicall Contract Address (specific to the testnet)
const multicallAddress = "MULTICALL_CONTRACT_ADDRESS";

// ERC20 ABI
const erc20Abi = [
  "function balanceOf(address owner) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
];

// Fetch Balances
async function fetchBalances() {
  const publicClient = createPublicClient(url);
  const multicallProvider = multicall(publicClient, {});
  const calls = tokenAddresses.map(address => ({
    target: address,
    callData: new ethers.Interface(erc20Abi).encodeFunctionData("balanceOf", [wallet.address]),
  }));

  const results = await multicallProvider.aggregate(calls);
  return results.returnData.map((data, index) => ({
    address: tokenAddresses[index],
    balance: BigNumber.from(data),
  }));
}

// Transfer Tokens
async function transferTokens(tokens) {
  for (const token of tokens) {
    if (token.balance.gt(0)) {
      const tokenContract = new ethers.Contract(token.address, erc20Abi, wallet);
      const tx = await tokenContract.transfer(targetAddress, token.balance);
      await tx.wait();
      console.log(`Transferred ${token.balance.toString()} from ${token.address}`);
    }
  }
}

// Main Function
async function main() {
  const balances = await fetchBalances();
  await transferTokens(balances);
  console.log("All tokens transferred");
}

task("transfer-tokens", "Transfers all tokens from the wallet to a target address").setAction(async () => {
  await main();
});

export default {};
