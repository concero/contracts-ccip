include .env.foundry
include ../../.env
include ../../.env.tokens
include ../../.env.clccip
include ../../.env.clf
include ../../.env.deployments

export $(shell sed 's/=.*//' .env.foundry)
export $(shell sed 's/=.*//' ../../.env)
export $(shell sed 's/=.*//' ../../.env.tokens)
export $(shell sed 's/=.*//' ../../.env.clccip)
export $(shell sed 's/=.*//' ../../.env.clf)
export $(shell sed 's/=.*//' ../../.env.deployments)

args =

all: test

install:
	grep -E '^\s*url' ../../.gitmodules | awk '{print $3}' | xargs -I {} forge install {}

test:
	forge test $(args)

run_local_base_fork:
	anvil --fork-url ${BASE_RPC_URL} --fork-block-number 17729705

.PHONY: all test

