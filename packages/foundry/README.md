## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Clone

```shell
git clone https://github.com/concero/scaffoldeth/tree/feat/DEXSwap
```

## Usage

### Build

```shell
$ cd cd packages/foundry
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

Rename the `.env.example` file to `.env` and update the `BASE_RPC_URL=` variable with `YOUR_KEY` from alchemy. Note the tests run on a Base Mainnet Fork. After updating the file, run the following command:

```shell
$ source .env
```

### Test

```shell
$ forge test
```