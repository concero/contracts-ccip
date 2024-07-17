// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_POLYGON_AMOY, USDC_ARBITRUM_SEPOLIA, USDC_BASE_SEPOLIA, USDC_OPTIMISM_SEPOLIA, USDC_AVALANCHE} from "./Constants.sol";
import {IStorage} from "./Interfaces/IStorage.sol";

error ConceroCommon_NotMessenger(address _messenger);
error ConceroCommon_ChainIndexOutOfBounds();
error ConceroCommon_TokenTypeOutOfBounds();

contract ConceroCommon {
  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;
  uint256 internal constant USDC_DECIMALS = 10 ** 6;
  uint256 internal constant STANDARD_TOKEN_DECIMALS = 10 ** 18;

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (isMessenger(msg.sender) == false) revert ConceroCommon_NotMessenger(msg.sender);
    _;
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(IStorage.CCIPToken token, IStorage.Chain _chainIndex) internal view returns (address) {
    address[5][2] memory tokens;

    // Initialize BNM addresses
    tokens[uint(IStorage.CCIPToken.bnm)][uint(IStorage.Chain.arb)] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[uint(IStorage.CCIPToken.bnm)][uint(IStorage.Chain.base)] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[uint(IStorage.CCIPToken.bnm)][uint(IStorage.Chain.opt)] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt
    tokens[uint(IStorage.CCIPToken.bnm)][uint(IStorage.Chain.pol)] = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4; // pol

    // Initialize USDC addresses
    tokens[uint(IStorage.CCIPToken.usdc)][uint(IStorage.Chain.arb)] = block.chainid == 42161 ? USDC_ARBITRUM : USDC_ARBITRUM_SEPOLIA;
    tokens[uint(IStorage.CCIPToken.usdc)][uint(IStorage.Chain.base)] = block.chainid == 8453 ? USDC_BASE : USDC_BASE_SEPOLIA;
    tokens[uint(IStorage.CCIPToken.usdc)][uint(IStorage.Chain.opt)] = block.chainid == 10 ? USDC_OPTIMISM : USDC_OPTIMISM_SEPOLIA;
    tokens[uint(IStorage.CCIPToken.usdc)][uint(IStorage.Chain.pol)] = block.chainid == 137 ? USDC_POLYGON : USDC_POLYGON_AMOY;
    tokens[uint(IStorage.CCIPToken.usdc)][uint(IStorage.Chain.avax)] = block.chainid == 43114 ? USDC_AVALANCHE : USDC_AVALANCHE;

    if (uint256(token) > tokens.length) revert ConceroCommon_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert ConceroCommon_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function isMessenger(address _messenger) internal pure returns (bool _isMessenger) {
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = 0x11111003F38DfB073C6FeE2F5B35A0e57dAc4715;
    messengers[1] = address(0);
    messengers[2] = address(0);
    messengers[3] = address(0);

    for (uint256 i; i < messengers.length; ) {
      if (_messenger == messengers[i]) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }

  ///////////////////////////
  /////INTERNAL FUNCTIONS////
  ///////////////////////////

  /**
   * @notice Internal function to convert USDC Decimals to LP Decimals
   * @param _amount the amount of USDC
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToUSDCDecimals(uint256 _amount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
  }
}
