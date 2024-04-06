/*
Custom Viem transport
- Compatible with Chainlink Functions
- Uses 2 requests to initialise Viem, instead of 5

Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */

custom({
  async request({ method, params }) {
    // Hardcoded responses
    if (method === 'eth_chainId') return '0x13881';
    if (method === 'eth_estimateGas') return '0x5208';
    if (method === 'eth_maxPriorityFeePerGas') return '0x3b9aca00';

    const req = {
      url,
      method: 'post',
      headers: { 'Content-Type': 'application/json' },
      data: { jsonrpc: '2.0', id: 1, method, params },
    };

    const response = await Functions.makeHttpRequest(req);

    if (response.error || !response.data.result) throw new Error('error');
    return response.data.result;
  },
});
