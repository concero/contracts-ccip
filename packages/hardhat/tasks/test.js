const { createWalletClient, custom } = await import("npm:viem@2.9.26");
const { privateKeyToAccount } = await import("npm:viem@2.9.16/accounts");
const { sepolia, arbitrumSepolia, baseSepolia, optimismSepolia, avalancheFuji } = await import("npm:viem@2.9.16/chains");

console.log("Hello, world!");
