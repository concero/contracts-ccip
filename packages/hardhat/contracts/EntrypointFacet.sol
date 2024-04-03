// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
import { CDiamond } from "./CDiamond.sol";
import { IDiamond } from "./interfaces/IDiamond.sol";

contract UserEntrypointFacet {
    CDiamond private diamond;

    constructor(address _diamond) {
        diamond = CDiamond(_diamond);
    }

    function executeTransaction(address to, uint256 value, bytes memory data) public payable {
        diamond.processTransaction(to, value, data);
    }
}
