// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {InfraCLF} from "./InfraCLF.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {ICCIP} from "./Interfaces/ICCIP.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
error ChainNotAllowed(uint64 chainSelector);

contract InfraCCIP is InfraCLF {
    using SafeERC20 for IERC20;

    ///////////////////////////////////////////////////////////
    //////////////////////// VARIABLES ////////////////////////
    ///////////////////////////////////////////////////////////

    uint64 private constant CCIP_CALLBACK_GAS_LIMIT = 150_000;

    ////////////////
    ///IMMUTABLES///
    ////////////////
    LinkTokenInterface internal immutable i_linkToken;
    IRouterClient internal immutable i_ccipRouter;

    ///////////////
    ///MODIFIERS///
    ///////////////
    /**
     * @notice CCIP Modifier to check receivers for a specific chain
     * @param _chainSelector Id of the destination chain
     */
    modifier onlyAllowListedChain(uint64 _chainSelector) {
        if (s_poolReceiver[_chainSelector] == address(0)) {
            revert ChainNotAllowed(_chainSelector);
        }
        _;
    }

    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    ) InfraCLF(_variables, _chainSelector, _chainIndex, _dexSwap, _pool, _proxy, _messengers) {
        i_linkToken = LinkTokenInterface(_link);
        i_ccipRouter = IRouterClient(_ccipRouter);
    }

    ///////////////////////////////////////////////////////////////
    ///////////////////////////Functions///////////////////////////
    ///////////////////////////////////////////////////////////////

    /**
     * @notice Sends USDC to the destination chain using CCIP
     * @param _destinationChainSelector The destination chain selector
     * @param _token the token to be send
     * @param _amount the amount of tokens to ben send
     * @param _pendingCCIPTransactions the pending transactions to be sent
     */
    function _sendTokenPayLink(
        uint64 _destinationChainSelector,
        address _token,
        uint256 _amount,
        SettlementTx[] memory _pendingCCIPTransactions
    ) internal onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {
        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ICCIP.CcipTxType.batchedSettlement,
            data: abi.encode(_pendingCCIPTransactions)
        });

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _token,
            _amount,
            _destinationChainSelector,
            ccipTxData
        );

        uint256 fees = i_ccipRouter.getFee(_destinationChainSelector, evm2AnyMessage);
        s_lastCCIPFeeInLink[_destinationChainSelector] = fees;

        i_linkToken.approve(address(i_ccipRouter), fees);
        IERC20(_token).approve(address(i_ccipRouter), _amount);

        messageId = i_ccipRouter.ccipSend(_destinationChainSelector, evm2AnyMessage);
    }

    /**
     * @notice Chainlink CCIP helper function to build the EVM2AnyMessage
     * @param _token the token to be send
     * @param _amount the amount of tokens to ben send
     * @param _destinationChainSelector The destination chain selector
     * @param _ccipTxData the CCIP transaction data
     */
    function _buildCCIPMessage(
        address _token,
        uint256 _amount,
        uint64 _destinationChainSelector,
        ICCIP.CcipTxData memory _ccipTxData
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(s_poolReceiver[_destinationChainSelector]),
                data: abi.encode(_ccipTxData),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: CCIP_CALLBACK_GAS_LIMIT})
                ),
                feeToken: address(i_linkToken)
            });
    }
}
