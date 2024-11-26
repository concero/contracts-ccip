

## Prerequisites
- Make sure CLF_JS_CODE_BRANCH in .env.clf is set to your current branch

# Proxies
Proxies (Pools or Infra) should be deployed FIRST
## Parent Pool
```bun hardhat deploy-parent-pool --network base --deployproxy --uploadsecrets --slotid <YOUR-SLOT-ID>```
## Child Pools
```bun hardhat deploy-child-pool --network <NON-BASE-NETWORKS> --deployproxy```
## Infra
```bun hardhat deploy-infra --deployproxy --network <ALL-NETWORKS> --uploadsecrets --slotid <YOUR-SLOT-ID>```
Note: --uploadsecrets should not be run for chains that you have run uploadsecrets for before, as it will overwrite the existing secret versions.

# Implementations

## Child Pools
```bun hardhat deploy-child-pool --network <NON-BASE-NETWORKS> --deployimplementation --setvars```

## LP Token
```bun hardhat deploy-lp-token --network base```

## Parent Pool
### Prerequisites
- Create Chainlink Automation subscription, https://automation.chain.link, use PARENT_POOL_PROXY_<YOUR-NETWORK> when specifying contract address.
- Top up your subscription with at least 0.1 LINK
- Obtain forwarder address from subscription webpage
- Update `PARENT_POOL_AUTOMATION_FORWARDER_BASE_SEPOLIA` in .env.deployments with this forwarder address

```bun hardhat deploy-parent-pool --network base --deployimplementation --setvars --slotid <YOUR-SLOT-ID>```

# Infra
```bun hardhat deploy-infra --network <ALL-NETWORKS> --deployimplementation --setvars --slotid <YOUR-SLOT-ID>```

## After deployment is complete
- Run `bun hardhat clf-script-build --all` to build all JS scripts
- Push the changes to the corresponding branch to publish new deployments in .env.deployments

For Child Pools:
- Top up each child pool with 1n USDC

For all contracts:
- Top up with LINK
