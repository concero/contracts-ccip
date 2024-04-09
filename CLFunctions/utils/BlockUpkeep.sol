// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ThreeBlockUpkeep is KeeperCompatibleInterface {
    uint public lastUpkeepBlockNumber;
    uint public constant BLOCKS_BETWEEN_UPKEEPS = 3;

    constructor() {
        lastUpkeepBlockNumber = block.number;
    }

    function checkUpkeep(bytes calldata /* checkData */)
    external
    override
    view
    returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = (block.number - lastUpkeepBlockNumber) > BLOCKS_BETWEEN_UPKEEPS;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // Ensure that we're only performing upkeep when needed
        require((block.number - lastUpkeepBlockNumber) > BLOCKS_BETWEEN_UPKEEPS, "Block requirement not met");

        // Your upkeep logic here
        // ...

        // Update the last upkeep block number
        lastUpkeepBlockNumber = block.number;
    }

}
