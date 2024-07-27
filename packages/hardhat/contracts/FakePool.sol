// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";

contract FakePool is CCIPReceiver {
    using SafeERC20 for IERC20;

    error ConceroPool_CallableOnlyByOwner(address caller, address owner);
    error ConceroPool_ItsNotAnOrchestrator(address caller);
    error ConceroPool_InvalidAddress();
    error ConceroPool_InsufficientBalance();

    address private immutable i_proxy;
    address private immutable i_owner;

    constructor(address _ccipRouter, address _proxy) CCIPReceiver(_ccipRouter) {
        i_proxy = _proxy;
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert ConceroPool_CallableOnlyByOwner(msg.sender, i_owner);
        _;
    }

    /**
     * @notice function to the Concero Orchestrator contract take loans
     * @param _token address of the token being loaned
     * @param _amount being loaned
     * @param _receiver address of the user that will receive the amount
     * @dev only the Orchestrator contract should be able to call this function
     * @dev for ether transfer, the _receiver need to be known and trusted
     */
    function takeLoan(address _token, uint256 _amount, address _receiver) external {
        if (msg.sender != i_proxy) revert ConceroPool_ItsNotAnOrchestrator(msg.sender);
        if (_receiver == address(0)) revert ConceroPool_InvalidAddress();
        if (_amount > IERC20(_token).balanceOf(address(this)))
            revert ConceroPool_InsufficientBalance();

        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function withdraw(address recipient, address token, uint256 amount) external payable onlyOwner {
        uint256 balance = LibConcero.getBalance(token, address(this));
        if (balance < amount) revert ConceroPool_InsufficientBalance();

        if (token != address(0)) {
            LibConcero.transferERC20(token, amount, recipient);
        } else {
            payable(recipient).transfer(amount);
        }
    }

    ////////////////
    /// INTERNAL ///
    ////////////////
    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {}
}
