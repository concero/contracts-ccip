"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const deployConceroPool = async function (hre) {
    const { deployments, getNamedAccounts, network } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    // THIS IS JUST AN EXAMPLE, PLEASE REPLACE WITH REAL ADDRESSES
    const USDC_ADDRESS = process.env.USDC_ARBITRUM;
    const USDT_ADDRESS = process.env.USDC_ARBITRUM_SEPOLIA;
    if (!USDC_ADDRESS || !USDT_ADDRESS) {
        throw new Error("USDC_ADDRESS and USDT_ADDRESS must be defined in the environment variables.");
    }
    console.log("Deploying ConceroPool...");
    const deploymentResult = await deploy("ConceroPool", {
        from: deployer,
        args: [USDC_ADDRESS, USDT_ADDRESS], // Constructor arguments
        log: true,
        autoMine: true,
    });
    console.log(`ConceroPool deployed to: ${deploymentResult.address}`);
    // Optional: Update deployment address in an environment file or elsewhere
    // updateEnvVariable("CONCERO_POOL_ADDRESS", deploymentResult.address, "../../.env");
};
exports.default = deployConceroPool;
deployConceroPool.tags = ["ConceroPool"];
