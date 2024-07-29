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
	grep -E '^\s*url' ../../.gitmodules | awk '{print $$3}' | xargs -I {} sh -c 'forge install {}'

run_fork:
	anvil --fork-url ${BASE_RPC_URL}


test:
	forge test $(args)

#test-fork: run_fork
#	forge test $(args)
#	$(MAKE) stop_local_base_fork

.PHONY: get_latest_block run_fork stop_local_fork test test-fork
.PHONY: all test

