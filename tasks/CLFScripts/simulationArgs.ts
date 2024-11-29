import {getEnvVar, getHashSum} from '../../utils';
import {
	collectLiquidityCodeUrl,
	ethersV6CodeUrl,
	infraSrcJsCodeUrl,
	parentPoolDistributeLiqJsCodeUrl,
} from '../../constants/functionsJsCodeUrls';

type ArgBuilder = () => Promise<string[]>;

const getSimulationArgs: {[functionName: string]: ArgBuilder} = {
	infra_src: async () => {
		const srcJsHashSum = getHashSum(await (await fetch(infraSrcJsCodeUrl)).text());
		const ethersHashSum = getHashSum(await (await fetch(ethersV6CodeUrl)).text());
		const placeholder = '0x0';
		const dstContractAddress = getEnvVar('CONCERO_INFRA_PROXY_ARBITRUM');
		const ccipMessageId = '0xf721b113e0a0401ba87f48aff9801c78f037cab36cb43c72bd115ccec7845d27';
		const sender = '0x70E73f067a1fC9FE6D53151bd271715811746d3a';
		const recipient = '0x70E73f067a1fC9FE6D53151bd271715811746d3a';
		const amount = '0x' + BigInt(100000000000000000).toString(16);
		const srcChainSelector = '0x' + BigInt(getEnvVar('CL_CCIP_CHAIN_SELECTOR_BASE')).toString(16);
		const dstChainSelector = '0x' + BigInt(getEnvVar('CL_CCIP_CHAIN_SELECTOR_ARBITRUM')).toString(16);
		const token = '0x' + BigInt(1).toString(16);
		const blockNumber = '0xA65233';
		const dstSwapData = '0x00';

		return [
			srcJsHashSum,
			ethersHashSum,
			placeholder,
			dstContractAddress,
			ccipMessageId,
			sender,
			recipient,
			amount,
			srcChainSelector,
			dstChainSelector,
			token,
			blockNumber,
			dstSwapData,
		];
	},
	infra_dst: async () => {
		return [
			'0x0',
			'0x0',
			'0x0',
			'0x' + BigInt(getEnvVar('CONCERO_INFRA_PROXY_ARBITRUM_SEPOLIA')).toString(16),
			'0x' + BigInt(getEnvVar('CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA')).toString(16),
			'0x064f6190edeced1d56cad0917491d69e28e6983908e20da84151f09a56db5654',
			'0x5d4060fd7de4931c2025652b1832e2d99058025c0c47c74dd5d5b85976358197',
		];
	},
	collect_liq: async () => {
		const srcJsHashSum = getHashSum(await (await fetch(collectLiquidityCodeUrl)).text());
		const ethersHashSum = getHashSum(await (await fetch(ethersV6CodeUrl)).text());
		const placeholder = '0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0';
		const liquidityRequestedFromEachPool = '0x147B0';
		const withdrawalId = '0x3e63da41d93846072a115187efd804333da52256b8ec17e9c05163d6903d561d';

		return [srcJsHashSum, ethersHashSum, placeholder, liquidityRequestedFromEachPool, withdrawalId];
	},
	pool_distribute_liq: async () => {
		const srcJsHashSum = getHashSum(await (await fetch(parentPoolDistributeLiqJsCodeUrl)).text());
		const ethersHashSum = getHashSum(await (await fetch(ethersV6CodeUrl)).text());
		const functionsReqType = '0x1';
		const newPoolChainSelector = '0x383a1891ae1915b1';
		const distributeLiquidityRequestId = '0x05f8cc312ae3687e5581353da9c5889b92d232f7776c8b81dc234fb330fda265';
		const distributionType = '0x1';

		return [
			srcJsHashSum,
			ethersHashSum,
			functionsReqType,
			newPoolChainSelector,
			distributeLiquidityRequestId,
			distributionType,
		];
	},
	pool_get_total_balance: async () => {
		const srcJsHashSum = '0xef64cf53063700bbbd8e42b0282d3d8579aac289ea03f826cf16f9bd96c7703a';
		const ethersHashSum = '0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4';

		return [srcJsHashSum, ethersHashSum];
	},
};

export default getSimulationArgs;
