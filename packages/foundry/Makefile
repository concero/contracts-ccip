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

test:
	forge test $(args)

.PHONY: all test
