// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";

contract ConceroParentPoolCCIP is ParentPoolStorage {
    ////////////////
    /// INTERNAL ///
    ////////////////
    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlistedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        // todo: this should be changed to a struct
        (address lpAddress, address user, uint256 receivedFee) = abi.decode(
            any2EvmMessage.data,
            (address, address, uint256)
        );

        bool isUserTx = receivedFee > 0 && user != address(0);
        bool isWithdrawalTx = lpAddress != address(0);

        if (isUserTx) {
            IStorage.Transaction memory transaction = IOrchestrator(i_infraProxy).getTransaction(
                any2EvmMessage.messageId
            );
            bool isExecutionLayerFailed = ((transaction.ccipMessageId == any2EvmMessage.messageId &&
                transaction.isConfirmed == false) || transaction.ccipMessageId == 0);
            if (isExecutionLayerFailed) {
                //We don't subtract fee here because the loan was not performed. And the value is not summed into the `s_loanInUse` variable.
                i_USDC.safeTransfer(user, any2EvmMessage.destTokenAmounts[0].amount);
            } else {
                //subtract the amount from the committed total amount
                uint256 amountAfterFees = (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);
                s_loansInUse -= amountAfterFees;
            }
        } else if (isWithdrawalTx) {
            bytes32 withdrawalId = s_withdrawalIdByLPAddress[lpAddress];
            if (withdrawalId == bytes32(0)) revert ConceroParentPool_RequestDoesntExist();
            WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

            request.remainingLiquidityFromChildPools = request.remainingLiquidityFromChildPools >=
                any2EvmMessage.destTokenAmounts[0].amount
                ? request.remainingLiquidityFromChildPools -
                    any2EvmMessage.destTokenAmounts[0].amount
                : 0;

            s_withdrawalsOnTheWayAmount = s_withdrawalsOnTheWayAmount >=
                any2EvmMessage.destTokenAmounts[0].amount
                ? s_withdrawalsOnTheWayAmount - any2EvmMessage.destTokenAmounts[0].amount
                : 0;

            s_withdrawAmountLocked += any2EvmMessage.destTokenAmounts[0].amount;
        }

        emit ConceroParentPool_CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
        );
    }

    /**
     * @notice helper function to distribute liquidity after LP deposits.
     * @param _usdcAmountToDeposit amount of USDC should be distributed to the pools.
     */
    function _distributeLiquidityToChildPools(uint256 _usdcAmountToDeposit) internal {
        uint256 childPoolsCount = s_poolChainSelectors.length;
        uint256 amountToDistribute = ((_usdcAmountToDeposit * PRECISION_HANDLER) /
            (childPoolsCount + 1)) / PRECISION_HANDLER;

        for (uint256 i; i < childPoolsCount; ) {
            bytes32 ccipMessageId = _ccipSend(s_poolChainSelectors[i], amountToDistribute);
            _addDepositOnTheWay(ccipMessageId, s_poolChainSelectors[i], amountToDistribute);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Function to distribute funds automatically right after LP deposits into the pool
     * @dev this function will only be called internally.
     */
    function _ccipSend(
        uint64 _chainSelector,
        uint256 _amountToDistribute
    ) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _chainSelector,
            address(i_USDC),
            _amountToDistribute
        );

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(_chainSelector, evm2AnyMessage);

        i_USDC.approve(i_ccipRouter, _amountToDistribute);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        messageId = IRouterClient(i_ccipRouter).ccipSend(_chainSelector, evm2AnyMessage);

        emit ConceroParentPool_CCIPSent(messageId, _chainSelector, s_childPools[_chainSelector]);
    }

    function _buildCCIPMessage(
        uint64 _chainSelector,
        address _token,
        uint256 _amount
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(s_childPools[_chainSelector]),
                data: abi.encode(address(0), address(0), 0), //Here the 1° address is (0) because this is the Parent Pool and we never send to withdraw in another place.
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 350_000})),
                feeToken: address(i_linkToken)
            });
    }
}
