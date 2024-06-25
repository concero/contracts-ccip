// import { Concero } from "../typechain-types";
// import "@nomicfoundation/hardhat-chai-matchers";
// import { WalletClient } from "viem/clients/createWalletClient";
// import { HttpTransport } from "viem/clients/transports/http";
// import { Chain } from "viem/types/chain";
// import type { Account } from "viem/accounts/types";
// import { RpcSchema } from "viem/types/eip1193";
// import { privateKeyToAccount } from "viem/accounts";
// import { Address, createPublicClient, createWalletClient, encodeAbiParameters, http, PrivateKeyAccount } from "viem";
// import { arbitrumSepolia, baseSepolia, optimismSepolia } from "viem/chains";
// import ERC20ABI from "../abi/ERC20.json";
// import { PublicClient } from "viem/clients/createPublicClient";
// import { abi as ConceroOrchestratorAbi } from "../artifacts/contracts/Orchestrator.sol/Orchestrator.json";
//
// const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
//
// const chainsMap = {
//   [process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA]: {
//     viemChain: optimismSepolia,
//     viemTransport: http(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
//   },
//   [process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA]: {
//     viemChain: baseSepolia,
//     viemTransport: http(`https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`),
//   },
//   [process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA]: {
//     viemChain: arbitrumSepolia,
//     viemTransport: http(),
//   },
// };
//
// const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
// const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA!;
// const senderAddress = process.env.TESTS_WALLET_ADDRESS as Address;
// const usdcAmount = "10000";
// const bnmAmount = "1500000000000000000";
// const bnmTokenAddress = process.env.CCIPBNM_BASE_SEPOLIA as Address;
// const usdTokenAddress = process.env.USDC_BASE_SEPOLIA as Address;
// const transactionsCount = 1;
// const srcContractAddress = process.env.CONCEROPROXY_BASE_SEPOLIA as Address;
// const dstContractAddress = process.env.CONCEROPROXY_OPTIMISM_SEPOLIA as Address;
//
// describe("swap\n", () => {
//   let Concero: Concero;
//   let srcPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
//     chain: chainsMap[srcChainSelector].viemChain,
//     transport: chainsMap[srcChainSelector].viemTransport,
//   });
//   let dstPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
//     chain: chainsMap[dstChainSelector].viemChain,
//     transport: chainsMap[dstChainSelector].viemTransport,
//   });
//
//   let viemAccount: PrivateKeyAccount = privateKeyToAccount(
//     ("0x" + process.env.TESTS_WALLET_PRIVATE_KEY) as `0x${string}`,
//   );
//   let nonce: BigInt;
//   let walletClient: WalletClient<HttpTransport, Chain, Account, RpcSchema> = createWalletClient({
//     chain: chainsMap[srcChainSelector].viemChain,
//     transport: chainsMap[srcChainSelector].viemTransport,
//     account: viemAccount,
//   });
//
//   before(async () => {
//     nonce = BigInt(
//       await srcPublicClient.getTransactionCount({
//         address: viemAccount.address,
//       }),
//     );
//   });
//
//   const callApprovals = async () => {
//     const approveToken = async (tokenAddress: string, amount: string) => {
//       const tokenAlowance = await srcPublicClient.readContract({
//         abi: ERC20ABI,
//         functionName: "allowance",
//         address: tokenAddress as `0x${string}`,
//         args: [senderAddress, srcContractAddress],
//       });
//
//       if (tokenAlowance >= BigInt(amount)) {
//         return;
//       }
//
//       const tokenAmount = await srcPublicClient.readContract({
//         abi: ERC20ABI,
//         functionName: "balanceOf",
//         address: tokenAddress as `0x${string}`,
//         args: [senderAddress],
//       });
//
//       const tokenHash = await walletClient.writeContract({
//         abi: ERC20ABI,
//         functionName: "approve",
//         address: tokenAddress as `0x${string}`,
//         args: [srcContractAddress, BigInt(tokenAmount)],
//         nonce: nonce++,
//       });
//
//       console.log("tokenApprovalHash: ", tokenHash);
//
//       return tokenHash;
//     };
//
//     const usdcHash = await approveToken(usdTokenAddress, usdcAmount);
//
//     if (!usdcHash) {
//       return;
//     }
//
//     await Promise.all([srcPublicClient.waitForTransactionReceipt({ hash: usdcHash })]);
//   };
//
//   it("should swap", async () => {
//     try {
//       await callApprovals();
//
//       const fromSrcBlockNumber = await srcPublicClient.getBlockNumber();
//       const fromDstBlockNumber = await dstPublicClient.getBlockNumber();
//       const dexRouterAddress = "0xF8908a808F1c04396B16A5a5f0A14064324d0EdA";
//
//       const dexData = encodeAbiParameters(
//         [{ type: "address" }, { type: "address[]" }, { type: "address" }, { type: "uint256" }],
//         [dexRouterAddress, [usdTokenAddress, bnmTokenAddress], senderAddress, 100n],
//       );
//
//       const swapData = [
//         {
//           dexType: 0n,
//           fromToken: usdTokenAddress,
//           fromAmount: BigInt(usdcAmount),
//           toToken: bnmTokenAddress,
//           toAmount: BigInt(bnmAmount),
//           toAmountMin: BigInt(bnmAmount),
//           dexData,
//         },
//       ];
//
//       console.log("swapData: ", swapData);
//
//       const transactionHash = await walletClient.writeContract({
//         abi: ConceroOrchestratorAbi,
//         functionName: "swap",
//         address: srcContractAddress as Address,
//         args: [swapData],
//         gas: 1_000_000n,
//       });
//
//       console.log("transactionHash: ", transactionHash);
//
//       await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });
//     } catch (error) {
//       console.error("Error: ", error);
//     }
//   }).timeout(0);
//
//   // it("should swapAndBridge", async () => {
//   //   try {
//   //     await callApprovals();
//   //
//   //     const dexRouterAddress = "0xF8908a808F1c04396B16A5a5f0A14064324d0EdA";
//   //
//   //     const dexData = encodeAbiParameters(
//   //       [{ type: "address" }, { type: "address[]" }, { type: "address" }, { type: "uint256" }],
//   //       [dexRouterAddress, [usdTokenAddress, bnmTokenAddress], srcContractAddress, 100n],
//   //     );
//   //
//   //     const swapData = [
//   //       {
//   //         dexType: 0n,
//   //         fromToken: usdTokenAddress,
//   //         fromAmount: BigInt(usdcAmount),
//   //         toToken: bnmTokenAddress,
//   //         toAmount: BigInt(bnmAmount),
//   //         toAmountMin: BigInt(bnmAmount),
//   //         dexData,
//   //       },
//   //     ];
//   //
//   //     const bridgeData = {
//   //       tokenType: 0n,
//   //       amount: BigInt(bnmAmount),
//   //       minAmount: BigInt(bnmAmount),
//   //       dstChainSelector: BigInt(dstChainSelector),
//   //       receiver: senderAddress,
//   //     };
//   //
//   //     const transactionHash = await walletClient.writeContract({
//   //       abi: ConceroOrchestratorAbi,
//   //       functionName: "swapAndBridge",
//   //       address: srcContractAddress as Address,
//   //       args: [bridgeData, swapData, []],
//   //       gas: 4_000_000n,
//   //     });
//   //
//   //     console.log("transactionHash: ", transactionHash);
//   //
//   //     await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });
//   //   } catch (error) {
//   //     console.error("Error: ", error);
//   //   }
//   // }).timeout(0);
// });
