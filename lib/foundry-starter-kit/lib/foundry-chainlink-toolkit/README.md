# Foundry-Chainlink Toolkit

> **Warning**
>
> **This package is currently in BETA.**
>
> **Open issues to submit bugs.**

**This is a toolkit that makes spinning up, managing and testing a local Chainlink nodes easier.**  

This project uses [Foundry](https://book.getfoundry.sh) tools to deploy and test smart contracts.  
It can be easily integrated into an existing Foundry project.

<!-- TOC -->
* [Foundry-Chainlink Toolkit](#foundry-chainlink-toolkit)
  * [Overview](#overview)
  * [Getting Started](#getting-started)
    * [Prepare local environment](#prepare-local-environment)
    * [Install Foundry-Chainlink Toolkit](#install-foundry-chainlink-toolkit)
    * [Set up environment variables](#set-up-environment-variables)
    * [Configure your project](#configure-your-project)
    * [Set up chain RPC node](#set-up-chain-rpc-node)
  * [Usage](#usage)
    * [Initialize testing environment](#initialize-testing-environment)
    * [Set up Chainlink Jobs](#set-up-chainlink-jobs)
      * [Direct Request Job](#direct-request-job)
      * [Cron Job](#cron-job)
      * [Webhook Job](#webhook-job)
      * [Keeper Job](#keeper-job)
      * [Flux Job](#flux-job)
      * [OCR Job](#ocr-job)
  * [Project Structure](#project-structure)
  * [Acknowledgements](#acknowledgements)
<!-- TOC -->

## Overview
The purpose of this project is to simplify the immersion in the development and testing of Smart Contracts using Chainlink oracles. This project is aimed primarily at those who use the Foundry toolchain.

## Getting Started

### Prepare local environment
1. Install Foundry toolchain. Reference the below commands or go to the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

    - MacOS/Linux
      ```
      curl -L https://foundry.paradigm.xyz | bash
      ```
      This will download foundryup. Restart your terminal session, then install Foundry by running:
      ```
      foundryup
      ```
      > **Note**  
        You may see the following error on MacOS:  
        ```dyld: Library not loaded: /usr/local/opt/libusb/lib/libusb-1.0.0.dylib```  
        In order to fix this, you should install libusb:  
        ```brew install libusb```   
        Reference: https://github.com/foundry-rs/foundry/blob/master/README.md#troubleshooting-installation

2. Install [GNU make](https://www.gnu.org/software/make/). The functionality of the project is wrapped in the [makefile](makefile). Reference the below commands based on your OS or go to [Make documentation](https://www.gnu.org/software/make/manual/make.html).

   - MacOS: install [Homebrew](https://brew.sh/) first, then run
      ```
      brew install make
      ```

    - Debian/Ubuntu
      ```
      apt install make
      ```

    - Fedora/RHEL
      ```
      yum install make
      ```

3. Install and run Docker; for convenience, the Chainlink nodes run in a container. Instructions: [docs.docker.com/get-docker](https://docs.docker.com/get-docker/).

> **Note**  
Foundry-Chainlink toolkit was tested using:
> - Forge 0.2.0 (e99cf83 2023-04-21T00:15:57.602861000Z)
> - GNU Make 3.81
> - Docker version 20.10.23, build 7155243

### Install Foundry-Chainlink Toolkit
The Foundry-Chainlink toolkit has been designed so that it can be installed as a Forge dependency.  

To integrate it into your project, you need to run the following command:
```
forge install smartcontractkit/foundry-chainlink-toolkit
```

In addition, the [Forge Standard Library](https://github.com/foundry-rs/forge-std) must be installed in your project:
```
forge install foundry-rs/forge-std
```

> **Note**  
> In addition to being used as a plugin, this toolkit is ready to be used as a demo standalone application.  
> In this case, to install dependencies, run:
> ```
> git submodule update
> ```

### Set up environment variables
Based on the [env.template](env.template) - create or update an `.env` file in the root directory of your project.
In most cases, you will not need to modify the default values specified in this file.

Below are comments on some environment variables:
- `FCT_PLUGIN_PATH` - path to the Foundry-Chainlink toolkit root
- `ETH_URL` - RPC node web socket used by the Chainlink node
- `RPC_URL` - RPC node http endpoint used by Forge
- `PRIVATE_KEY` - private key of an account used for deployment and interaction with smart contracts. Once Anvil is started, a set of private keys for local usage is provided. Use one of these for local development
- `ROOT` - root directory of the Chainlink node
- `CHAINLINK_CONTAINER_NAME` - Chainlink node container name for the possibility of automating communication with it
- `COMPOSE_PROJECT_NAME` - Docker network project name for the possibility of automating communication with it, more on it: https://docs.docker.com/compose/environment-variables/envvars/#compose_project_name

> **Note**  
> If environment variables related to a Chainlink node, including a Link Token contract address, were changed during your work you should run the ```make fct-run-nodes``` command in order for them to be applied.

### Configure your project
  - Give Forge permission to read the output directory of the toolkit by adding this setting to the foundry.toml:  
    ```
    fs_permissions = [{ access = "read", path = "lib/foundry-chainlink-toolkit/out"}]
    ```
    > **Note**  
    The default path to the root of the Foundry-Chainlink toolkit is `lib/foundry-chainlink-toolkit`.  
    Unfortunately at the moment `foundry.toml` cannot read all environment variables. Specify a different path if necessary.

  - Incorporate the [makefile-external](makefile-external) into your project. To do this, create or update a makefile in the root of your project with:
    ```
    -include ${FCT_PLUGIN_PATH}/makefile-external
    ```

### Set up chain RPC node
In order for a Chainlink node to be able to interact with the blockchain, and to interact with the blockchain using the [Forge](https://book.getfoundry.sh/forge/), you have to know an RPC node http endpoint and web socket for a chosen network compatible with Chainlink.
In addition to the networks listed in [this list](https://docs.chain.link/chainlink-automation/supported-networks/), Chainlink is compatible with any EVM-compatible networks.

For local testing, we recommend using [Anvil](https://book.getfoundry.sh/anvil/), which is a part of the Foundry toolchain.  
You can run it using the following command:
```
make fct-anvil
```

> **Note**  
> In case the local Ethereum node has been restarted, you should also [re-initialize the Chainlink cluster](#initialize-testing-environment) or perform a [clean spin-up of the Chainlink nodes](DOCUMENTATION.md#restart-a-chainlink-cluster) to avoid possible synchronization errors.

## Usage
Scripts for automating the initialization of the test environment and setting up Chainlink jobs will be described below.  

To display autogenerated help with a brief description of the most commonly used scripts, run:
```
make fct-help
```
For a more detailed description of the available scripts, you can refer to [DOCUMENTATION.md](DOCUMENTATION.md).

### Initialize testing environment
```
make fct-init
```
[This command](DOCUMENTATION.md#initialize-test-environment) automatically initializes the test environment, in particular, it makes clean spin-up of a Chainlink cluster of 5 Chainlink nodes.

Once Chainlink cluster is launched, a Chainlink nodes' Operator GUI will be available at:
- http://127.0.0.1:6711 - Chainlink node 1
- http://127.0.0.1:6722 - Chainlink node 2
- http://127.0.0.1:6733 - Chainlink node 3
- http://127.0.0.1:6744 - Chainlink node 4
- http://127.0.0.1:6755 - Chainlink node 5

For authorization, you must use the credentials specified in the [chainlink_api_credentials](chainlink%2Fsettings%2Fchainlink_api_credentials).

You can also initialize the test environment manually by following these steps:
1. [Deploy Link Token contract](DOCUMENTATION.md#deploy-link-token-contract)
2. Set `LINK_TOKEN_CONTRACT` in `.env`
3. [Spin up a Chainlink nodes cluster](DOCUMENTATION.md#spin-up-a-chainlink-cluster)
4. [Fund Chainlink nodes with ETH](DOCUMENTATION.md#transfer-eth-to-chainlink-nodes)
5. [Fund Chainlink nodes with Link tokens](DOCUMENTATION.md#transfer-link-tokens-to-chainlink-nodes)

> **Note**  
> For **ARM64** users. When starting a docker container, there will be warnings:  
> ```The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested```  
> You can safely ignore these warnings, container will start normally.

### Set up Chainlink Jobs
```
make fct-setup-job
```
[This command](DOCUMENTATION.md#set-up-a-chainlink-job) displays a list of available Chainlink jobs and sets up the selected one.

You can also set up a Chainlink job by calling the respective command.

#### Direct Request Job
```
make fct-setup-direct-request-job
```
[This command](DOCUMENTATION.md#set-up-direct-request-job) automatically sets up a Direct Request job.

You can also set up a Direct Request job manually by following these steps:
1. [Deploy Oracle contract](DOCUMENTATION.md#deploy-oracle-contract)
2. [Deploy Consumer contract](DOCUMENTATION.md#deploy-consumer-contract)
3. [Fund Consumer contract with Link tokens](DOCUMENTATION.md#transfer-link-tokens)
4. [Create Direct Request Job](DOCUMENTATION.md#create-chainlink-direct-request-job)
5. [Request ETH price with Consumer contract, a corresponding job will be launched](DOCUMENTATION.md#request-eth-price)
6. [Get ETH price after completing a job](DOCUMENTATION.md#get-eth-price)

#### Cron Job
```
make fct-setup-cron-job
```
[This command](DOCUMENTATION.md#set-up-cron-job) automatically sets up a Cron job.

You can also set up a Cron job manually by following these steps:
1. [Deploy Cron Consumer contract](DOCUMENTATION.md#deploy-cron-consumer-contract)
2. [Create Cron Job](DOCUMENTATION.md#create-chainlink-cron-job)
3. [Get ETH price after completing a job](DOCUMENTATION.md#get-eth-price--cron-)

#### Webhook Job
```
make fct-setup-webhook-job
```
[This command](DOCUMENTATION.md#set-up-webhook-job) automatically sets up a Webhook job.

You can also set up a Webhook job manually by following these steps:
1. [Create Webhook Job](DOCUMENTATION.md#create-chainlink-webhook-job)
2. [Run Webhook Job](DOCUMENTATION.md#run-chainlink-webhook-job)

#### Keeper Job
```
make fct-setup-keeper-job
```
[This command](DOCUMENTATION.md#set-up-keeper-job) automatically sets up a Keeper job.

You can also set up a Keeper job manually by following these steps:
1. [Deploy Keeper Consumer contract](DOCUMENTATION.md#deploy-keeper-consumer-contract)
2. [Deploy Registry contract](DOCUMENTATION.md#deploy-keeper-registry-contract)
3. [Create Keeper Jobs for Chainlink nodes in a cluster](DOCUMENTATION.md#create-chainlink-keeper-jobs)
4. [Register Chainlink nodes as keepers in a Registry contract](DOCUMENTATION.md#set-keepers)
5. [Register Keeper Consumer as upkeep in a Registry contract](DOCUMENTATION.md#register-keeper-consumer)
6. [Fund the latest upkeep in a Registry contract](DOCUMENTATION.md#fund-latest-upkeep)
7. [Get value of `counter` variable in a Keeper contract](DOCUMENTATION.md#get-keeper-counter)

#### Flux Job
```
make fct-setup-flux-job
```
[This command](DOCUMENTATION.md#set-up-flux-job) automatically sets up a Flux job.

You can also set up a Flux job manually by following these steps:
1. [Deploy Flux Aggregator contract](DOCUMENTATION.md#deploy-flux-aggregator-contract)
2. [Fund Flux Aggregator contract with Link tokens](DOCUMENTATION.md#transfer-link-tokens)
3. [Update Flux Aggregator available funds](DOCUMENTATION.md#update-available-funds)
4. [Set Flux Aggregator oracles](DOCUMENTATION.md#set-oracles)
5. [Create Flux Jobs for the first 3 Chainlink nodes in a cluster](DOCUMENTATION.md#create-chainlink-flux-jobs)
6. [Get the answer of the latest Flux round from the Flux Aggregator contract](DOCUMENTATION.md#get-flux-latest-answer)

#### OCR Job
```
make fct-setup-ocr-job
```
[This command](DOCUMENTATION.md#set-up-flux-job) automatically sets up an OCR job.

You can also set up a OCR job manually by following these steps:
1. [Deploy Offchain Aggregator contract](DOCUMENTATION.md#deploy-offchain-aggregator-contract)
2. [Set Offchain Aggregator payees](DOCUMENTATION.md#set-payees)
3. [Set Offchain Aggregator config](DOCUMENTATION.md#set-config)
4. [Create OCR Job for a bootstrap Chainlink node (first in a cluster)](DOCUMENTATION.md#create-chainlink-ocr--bootstrap--job)
5. [Create OCR Jobs for Chainlink nodes in a cluster except the first one (bootstrap)](DOCUMENTATION.md#create-chainlink-ocr-jobs)
6. [Request new OCR round in the Offchain Aggregator contract (optional)](DOCUMENTATION.md#request-new-round)
7. [Get the answer of the latest OCR round from the Offchain Aggregator contract](DOCUMENTATION.md#get-ocr-latest-answer)

> **Note**
> Manual set up of a Chainlink Job is recommended when utilizing a custom Consumer or Aggregator contract, or when a different job configuration is desired.  
> You can create a custom TOML file and use it to create a Chainlink Job instance through the Operator GUI or develop a custom script using the existing scripts provided by this toolkit.

## Project Structure

### Chainlink [*](chainlink)
This directory contains configuration files, scripts and smart contracts source code.

#### Contracts [*](chainlink%2Fcontracts)
- [ChainlinkConsumer.sol](chainlink%2Fcontracts%2FChainlinkConsumer.sol) - example consumer contract for [Chainlink Direct Request Job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs/#direct-request-jobs)
- [ChainlinkCronConsumer.sol](chainlink%2Fcontracts%2FChainlinkCronConsumer.sol) - example consumer contract for [Chainlink Cron Job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#solidity-cron-jobs)
- [ChainlinkKeeperConsumer.sol](chainlink%2Fcontracts%2FChainlinkKeeperConsumer.sol) - example consumer contract for [Chainlink Keeper Job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#keeper-jobs)
- [LinkToken.sol](chainlink%2Fcontracts%2FLinkToken.sol) - flattened [Link Token contract](https://github.com/smartcontractkit/LinkToken)

#### Jobs [*](chainlink%2Fjobs)
- [cron_job.toml](chainlink%2Fjobs%2Fcron_job.toml) - example configuration file for a Chainlink [Cron job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#solidity-cron-jobs)
- [direct_request_job.toml](chainlink%2Fjobs%2Fdirect_request_job.toml) - example configuration file for a Chainlink [Direct Request job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#direct-request-jobs)
- [flux_job.toml](chainlink%2Fjobs%2Fflux_job.toml) - example configuration file for a Chainlink [Flux job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#flux-monitor-jobs)
- [keeper_job.toml](chainlink%2Fjobs%2Fkeeper_job.toml) - example configuration file for a Chainlink [Keeper job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#keeper-jobs)
- [ocr_job.toml](chainlink%2Fjobs%2Focr_job.toml) - example configuration file for a Chainlink [OCR job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#off-chain-reporting-jobs)
- [ocr_job_bootstrap.toml](chainlink%2Fjobs%2Focr_job_bootstrap.toml) - example configuration file for a Chainlink OCR (bootstrap) job
- [webhook_job.toml](chainlink%2Fjobs%2Fwebhook_job.toml) - example configuration file for a Chainlink [Webhook job](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs/#webhook-jobs)

> **Note**  
> More info on Chainlink v2 Jobs, their types and configuration can be found here: [docs.chain.link/chainlink-nodes/oracle-jobs/jobs/](https://docs.chain.link/chainlink-nodes/oracle-jobs/jobs/).  
> You can change these configuration according to your requirements.

#### Setting [*](chainlink%2Fsettings)
- [chainlink_api_credentials](chainlink%2Fsettings%2Fchainlink_api_credentials) - Chainlink API credentials
- [chainlink_password](chainlink%2Fsettings%2Fchainlink_password) - Chainlink password

> **Note**  
> More info on authentication can be found here [github.com/smartcontractkit/chainlink/wiki/Authenticating-with-the-API](https://github.com/smartcontractkit/chainlink/wiki/Authenticating-with-the-API).  
> You can specify any credentials there. Password provided must be 16 characters or more.

#### SQL [*](chainlink%2Fsql)
- [create_tables.sql](chainlink%2Fsql%2Fcreate_tables.sql) - sql script to create tables related to Chainlink nodes in a Postgres DB
- [drop_tables.sql](chainlink%2Fsql%2Fdrop_tables.sql) - sql script to delete tables related to Chainlink nodes in a Postgres DB

#### Chainlink nodes logs directories
Once Chainlink nodes are started, log directories will be created for each of them.

#### chainlink.env [*](chainlink%2Fchainlink.env)
This file contains environment variables related to Chainlink node configuration. You can modify it according to your requirements.  
More info on Chainlink environment variables can be found here: https://docs.chain.link/chainlink-nodes/v1/configuration.

> **Note**  
> Subdirectories: [jobs](chainlink%2Fjobs), [settings](chainlink%2Fsettings) and [sql](chainlink%2Fsql) are used as shared folders for running Chainlink nodes and Postgres DB containers.

### External [*](external)
This directory contains external libraries.

#### OCRHelper [*](external%2FOCRHelper)
This Go library is based on https://github.com/smartcontractkit/chainlink integration tests and is used to prepare configuration parameters for Offchain Aggregator contract.  
It has pre-built binaries for platforms: darwin/amd64(x86_64), darwin/arm64, linux/amd64(x86_64), linux/arm,linux/arm64.
> **Note**  
> If you use another platform, in the root of the project please run:  
> ```make fct-build-ocr-helper```  
> It will build the external library for your platform.  
> It requires Go (1.18 or higher) installed.

### Script [*](script)
This directory contains Solidity Scripts to deploy and interact with Solidity smart contracts:
- Link Token
- Oracle
- Registry
- Flux and Offchain aggregators
- Chainlink Consumer contracts
- Helper Solidity Scripts

You can run these scripts with the command: `forge script path/to/script [--args]`. Logs and artifacts dedicated to each script run, including a transaction hash and an address of a deployed smart contract, are stored in a corresponding subdirectory of the [broadcast](broadcast) folder (created automatically).  
More info on Foundry Solidity Scripting can be found here: https://book.getfoundry.sh/tutorials/solidity-scripting?highlight=script#solidity-scripting.  
More info on `forge script` can be found here: https://book.getfoundry.sh/reference/forge/forge-script.

### Src [*](src)
#### Interfaces [*](src%2Finterfaces)
This directory contains interfaces to interact with Solidity contracts deployed using its pre-built artifacts. This is necessary in order to reduce dependence on a specific version of Solidity compiler.

#### Mocks [*](src%2Fmocks)
This directory contains mock Solidity contracts used for testing purposes:
- [MockAccessController.sol](src%2Fmocks%2FMockAccessController.sol) - mock contract used during deployment of Offchain Aggregator contract
- [MockAggregatorValidator.sol](src%2Fmocks%2FMockAggregatorValidator.sol) - mock contract used during deployment of Flux Aggregator contract
- [MockEthFeed.sol](src%2Fmocks%2FMockEthFeed.sol) - mock contract used during deployment of Registry contract
- [MockGasFeed.sol](src%2Fmocks%2FMockGasFeed.sol) - mock contract used during deployment of Registry contract

> **Note**  
> Foundry-Chainlink toolkit intended to support different compiler versions in range `[>=0.6.2 <0.9.0]`.  
> It was tested e2e with these solc versions:
> - 0.6.2
> - 0.6.12
> - 0.7.6
> - 0.8.12
>
> Therefore, you can specify any supported Solidity compiler version in your foundry.toml.  
> In case you find any problems you are welcome to open an issue.

## Acknowledgements
This project based on https://github.com/protofire/hardhat-chainlink-plugin. 
