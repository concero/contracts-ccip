# Makefile for running foundry tests
# Usage:
# - Prerequisites:
#   - Run `yarn install` to install all dependencies via Yarn.
#   - Run `foundryup` to ensure Foundry is up-to-date.
#   - Run `forge install` to install all foundry dependencies.
# - Commands:
#   - `make install`         : Install all dependencies defined in .gitmodules using Foundry's forge install.
#   - `make run_fork`        : Run an anvil fork on the BASE_LOCAL_FORK_PORT using the base RPC URL.
#   - `make run_arb_fork`    : Run an anvil fork on the ARB_LOCAL_FORK_PORT using the ARB RPC URL.
#   - `make test`            : Run all tests using forge with any optional arguments specified in --args.
#                              For example: `make test --args="--match-test Deposit"`

include .env.foundry
include ../../.env
include ../../.env.tokens
include ../../.env.clccip
include ../../.env.clf
include ../../.env.deployments.mainnet
include ../../.env.deployments.testnet
include ../../.env.wallets

ENV_FILES := .env.foundry ../../.env ../../.env.tokens ../../.env.clccip ../../.env.clf ../../.env.deployments.mainnet ../../.env.deployments.testnet ../../.env.wallets
export $(shell cat $(ENV_FILES) | sed 's/=.*//' | sort | uniq)
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

