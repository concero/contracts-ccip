// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.20;

// import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
// import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
// import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

// contract DstJsRemix {
//     enum CCIPToken {
//         bnm,
//         usdc
//     }

//     struct BridgeData {
//         CCIPToken tokenType;
//         uint256 amount;
//         uint64 dstChainSelector;
//         address receiver;
//     }

//     IRouterClient internal immutable i_ccipRouter;
//     LinkTokenInterface internal immutable i_linkToken;

//     event CCIPSent(
//         bytes32 indexed ccipMessageId,
//         address sender,
//         address recipient,
//         CCIPToken token,
//         uint256 amount,
//         uint64 dstChainSelector,
//         bytes32 indexed dstSwapDataHashSum
//     );

//     constructor(address _router, address _link) {
//         i_ccipRouter = IRouterClient(_router);
//         i_linkToken = LinkTokenInterface(_link);
//     }

//     function testEvent() external {
//         BridgeData memory bridgeData = BridgeData({
//             tokenType: CCIPToken.bnm,
//             amount: 1_000_000,
//             dstChainSelector: 3478487238524512106,
//             receiver: msg.sender
//         });
//         IDexSwap.SwapData[] memory dstSwapData;

//         bytes32 ccipMessageId = _sendTokenPayLink(
//             bridgeData.dstChainSelector,
//             fromToken,
//             amountToSend,
//             bridgeData.receiver,
//             lpFee
//         );

//         bytes32 dstSwapDataHashSum = keccak256(abi.encode(ccipMessageId, bridgeData, dstSwapData));

//         emit CCIPSent(
//             ccipMessageId,
//             msg.sender,
//             msg.sender,
//             1,
//             1_000_000,
//             3478487238524512106, // arb sepolia
//             dstSwapDataHashSum
//         );
//     }

//     /*//////////////////////////////////////////////////////////////
//                                 INTERNAL
//     //////////////////////////////////////////////////////////////*/
//     function _sendTokenPayLink(
//         uint64 _destinationChainSelector,
//         address _token,
//         uint256 _amount,
//         address _receiver,
//         uint256 _lpFee
//     ) internal onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {
//         Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
//             _token,
//             _amount,
//             _receiver,
//             _lpFee,
//             _destinationChainSelector
//         );

//         uint256 fees = i_ccipRouter.getFee(_destinationChainSelector, evm2AnyMessage);

//         i_linkToken.approve(address(i_ccipRouter), fees);
//         IERC20(_token).approve(address(i_ccipRouter), _amount);

//         messageId = i_ccipRouter.ccipSend(_destinationChainSelector, evm2AnyMessage);
//     }

//     function _buildCCIPMessage(
//         address _token,
//         uint256 _amount,
//         address _receiver,
//         uint256 _lpFee,
//         uint64 _destinationChainSelector
//     ) internal view returns (Client.EVM2AnyMessage memory) {
//         Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
//         tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

//         return
//             Client.EVM2AnyMessage({
//                 receiver: abi.encode(s_poolReceiver[_destinationChainSelector]),
//                 data: abi.encode(address(0), _receiver, _lpFee),
//                 tokenAmounts: tokenAmounts,
//                 extraArgs: Client._argsToBytes(
//                     Client.EVMExtraArgsV1({gasLimit: CCIP_CALLBACK_GAS_LIMIT})
//                 ),
//                 feeToken: address(i_linkToken)
//             });
//     }
// }

// interface IDexSwap {
//     ///@notice Concero Enum to track DEXes
//     enum DexType {
//         UniswapV2,
//         UniswapV2FoT,
//         SushiV3Single,
//         UniswapV3Single,
//         SushiV3Multi,
//         UniswapV3Multi,
//         Aerodrome,
//         AerodromeFoT,
//         UniswapV2Ether,
//         WrapNative,
//         UnwrapWNative
//     }

//     ///@notice Concero Struct to track DEX Data
//     struct SwapData {
//         DexType dexType;
//         address fromToken;
//         uint256 fromAmount;
//         address toToken;
//         uint256 toAmount;
//         uint256 toAmountMin;
//         bytes dexData; //routerAddress + data left to do swap
//     }
// }
