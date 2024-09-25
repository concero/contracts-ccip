include .env.foundry
include ../../.env
include ../../.env.tokens
include ../../.env.clccip
include ../../.env.clf
include ../../.env.deployments.mainnet
include ../../.env.deployments.testnet
include ../../.env.wallets

export $(shell sed 's/=.*//' .env.foundry)
export $(shell sed 's/=.*//' ../../.env)
export $(shell sed 's/=.*//' ../../.env.tokens)
export $(shell sed 's/=.*//' ../../.env.clccip)
export $(shell sed 's/=.*//' ../../.env.clf)
export $(shell sed 's/=.*//' ../../.env.deployments.mainnet)
export $(shell sed 's/=.*//' ../../.env.deployments.testnet)
export $(shell sed 's/=.*//' ../../.env.wallets)

ARB_LOCAL_FORK_PORT=8546
BASE_LOCAL_FORK_PORT=8545

args =

all: test

install:
	grep -E '^\s*url' ../../.gitmodules | awk '{print $$3}' | xargs -I {} sh -c 'forge install {}'

run_fork:
	anvil --fork-url ${BASE_RPC_URL} -p ${BASE_LOCAL_FORK_PORT}

run_arb_fork:
	anvil --fork-url ${ARB_RPC_URL} -p ${ARB_LOCAL_FORK_PORT}

test:
	forge test $(args)

.PHONY: all test

