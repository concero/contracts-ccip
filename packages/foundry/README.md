## Foundry

**Foundry is a blazing fast, portable, and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Usage

### Build

```shell
$ cd packages/foundry
```

```shell
$ yarn install
```

```shell
$ foundryup
```

```shell
$ forge build
```

### Env file

Rename the `.env.example` file to `.env` and update the `BASE_RPC_URL=` & `ARB_RPC_URL=` variable with `YOUR_KEY` from alchemy. Note the tests run on a Base & Arbitrum Mainnet Fork. After updating the file, run the following command:

```shell
$ source .env
```

### Test

```shell
$ forge test
```

## About Tests

The tests related to this pool's implementation are inside the `Pos-Upgradeable` folder.

We have some unit tests focused on setters and reverts, local integration tests using ccipLocal, and forked tests. Local and Forked ccip-related tests are complementary because we fork the mainnet environment, and it's not possible to transfer USDC through the forked environment.

Our tests don't cover Automation & Functions, once the JavaScript code is still under development.

## Attention Points

- `ConceroPool.sol` & `ConceroChildPool.sol` only accepts `USDC`. So, the loss of precision is greater than other tokens.
- `ConceroPool.sol::_updateDepositInfoAndMintLPTokens`: Calculation of LP tokens to be minted.
  - It should be always proportional. Users must not receive bigger or lesser amounts
- `ConceroPool.sol::startWithdraw`: Initiate the withdraw process by trigging `Chainlink Functions` to get cross-chain totals.
  - `Chainlink Functions` must push the updated withdraw request to the `ConceroAutomation.sol` after the `fulfillRequest` fallback.
  - Liquidity Provider must never be able to open multiple requests
- `ConceroPool.sol::_updateUsdcAmountEarned`: Calculation of USDC earned during liquidity provision
  - Liquidity Provider must receive always an equal or greater amount of USDC than he deposited.
  - It must be always proportional to the amount of LPToken input amount.
- `ConceroAutomation.sol` must check the condition of each request. If `block.timestamp > deadline`, which is 6 days & 22 hours, `Automation` must `performUpkeep` by triggering `ChainlinkFunctions` to initiate cross-chain transfers.
  - The input amount of this call is `withdrawAmount / number of cross-chain pools + master`.
- `ConceroPool.sol::completeWithdraw`: must never process a withdraw that:
  - Didn't receive the full `amountEarned` checked in `receivedAmount`.
  - Do not burn the `LPToken` amount previously informed on `ConceroPool.sol::startWithdraw`.

## Scope

```
- contracts/ParentPool.sol
- contracts/ConceroChildPool.sol
- contracts/ConceroAutomation.sol
- contracts/LPToken.sol**
- Libraries/ParentPoolStorage.sol - it's ParentPool.sol Storage
- Libraries/ChildPoolStorage.sol - it's ConceroChildPool.sol Storage
- Proxy/ParentPoolProxy.sol***
- Proxy/ChildPoolProxy.sol***
```

- ** Open Zeppelin contract
- *** Open Zeppelin contract with the following adjustments:
   - Receive a `SAFE_LOCK` that allows us to stop all transactions
   - Removal of `ProxyAdmin`
   - Implementation of a new `_implementationOwner` to deal with storage updates.

## Known Issues that we need help with
- Loss of precision in fee calculation leading to DDOS + Funds Lost to the last withdrawer. It will only happen if the user enters the full amount of LPtokens received when depositing. If some 'dust' is left, the withdrawal will not collapse.
  - I managed to avoid DDOS. However, it still exists. On the other hand, the pool will receive Concero money as an initiator and this money will be present there since the deployment helping us override the issue.
