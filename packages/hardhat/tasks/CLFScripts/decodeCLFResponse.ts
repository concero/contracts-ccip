import {AbiParameter, decodeAbiParameters} from 'viem';

const responseDecoders: {[key: string]: AbiParameter[]} = {
	infra_src: [
		{type: 'uint256', name: 'dstGasPrice'},
		{type: 'uint256', name: 'srcGasPrice'},
		{type: 'uint64', name: 'dstChainSelector'},
		{type: 'uint256', name: 'linkUsdcRate'},
		{type: 'uint256', name: 'nativeUsdcRate'},
		{type: 'uint256', name: 'linkNativeRate'},
	],
	infra_dst: [{type: 'uint256', name: 'messageId'}],
	pool_get_total_balance: [
		{type: 'uint256', name: 'childPoolsLiquidity'},
		{type: 'bytes1[]', name: 'depositsOnTheWayIdsToDelete'},
	],
	pool_distribute_liq: [
		{type: 'uint256', name: 'childPoolsLiquidity'},
		{type: 'bytes1[]', name: 'depositsOnTheWayIdsToDelete'},
	],
};
/**
 * Decodes the response hex string based on the script name.
 * @param scriptName - The name of the script.
 * @param responseHex - The hex string response to decode.
 * @returns An object containing the decoded values.
 */
export function decodeCLFResponse(scriptName: string, responseHex: string): any {
	const decoder = responseDecoders[scriptName];
	if (!decoder) {
		console.error(`No decoder defined for script: ${scriptName}`);
		return null;
	}

	const responseData = responseHex.startsWith('0x') ? responseHex : '0x' + responseHex;

	try {
		const decodedValues = decodeAbiParameters(decoder, responseData);
		const result: Record<string, any> = {};

		decoder.forEach((param, index) => {
			result[param.name || `param${index}`] = decodedValues[index];
		});

		return result;
	} catch (error) {
		console.error('Failed to decode response:', error);
		return null;
	}
}
