// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {ParentPoolDeploy} from "../../script/ParentPoolDeploy.s.sol";

contract Deposit is Test {
    ParentPoolDeploy parentPoolDeploy;

    function beforeTestSetup() {
        parentPoolDeploy = new ParentPoolDeploy();
    }
}
