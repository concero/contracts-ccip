// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Base_Test} from "./Base_Test.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WithdrawTest is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address liquidityProvider = makeAddr("liquidityProvider");
    IERC20 usdc = IERC20(address(vm.envAddress("USDC_BASE")));

    uint256 constant LP_BALANCE = 10_000_000_000; // 10k usdc

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @dev run the Base Test setUp
        Base_Test.setUp();

        /// @dev fund liquidityProvider with lp tokens
        deal(address(parentPoolImplementation.i_lp()), liquidityProvider, LP_BALANCE);
        assertEq(IERC20(parentPoolImplementation.i_lp()).balanceOf(liquidityProvider), LP_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            START WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal() public {
        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        require(success, "Function call failed");
    }
}
