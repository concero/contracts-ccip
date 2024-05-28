// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IConceroCommon} from "./IConcero.sol";

contract ConceroCommon is ConfirmedOwner, IConceroCommon {

  uint64 internal immutable i_chainSelector;
  Chain internal immutable i_chainIndex;

  mapping(uint64 chainSelector => address conceroContract) internal s_conceroContracts;
  mapping(address messenger => bool allowed) internal s_messengerContracts;

  constructor(uint64 _chainSelector, uint _chainIndex) ConfirmedOwner(msg.sender) {
    i_chainSelector = _chainSelector;
    i_chainIndex = Chain(_chainIndex);
  }

  function setConceroContract(uint64 _chainSelector, address _conceroContract) external onlyOwner {
    s_conceroContracts[_chainSelector] = _conceroContract;

    emit ConceroContractUpdated(_chainSelector, _conceroContract);
  }

  function setConceroMessenger(address _walletAddress) external onlyOwner {
    if(_walletAddress == address(0)) revert InvalidAddress();
    if(s_messengerContracts[_walletAddress] == true) revert AddressAlreadyAllowlisted();

    s_messengerContracts[_walletAddress] = true;

    emit MessengerUpdated(_walletAddress, true);
  }

  //@audit we can merge setConceroMessenger & removeConceroMessenger
  function removeConceroMessenger(address _walletAddress) external onlyOwner {
    if(_walletAddress == address(0)) revert InvalidAddress();
    if(s_messengerContracts[_walletAddress] == false) revert NotAllowlistedOrAlreadyRemoved();

    s_messengerContracts[_walletAddress] = false;

    emit MessengerUpdated(_walletAddress, true);
  }

  function getToken(CCIPToken token) internal view returns (address) {
    address[3][2] memory tokens;

    // Initialize BNM addresses
    tokens[0][0] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[0][1] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[0][2] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt

    // Initialize USDC addresses
    tokens[1][0] = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // arb
    tokens[1][1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // base
    tokens[1][2] = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7; // opt

    if(uint256(token) > tokens.length) revert TokenTypeOutOfBounds();
    if(uint256(i_chainIndex) > tokens[uint256(token)].length) revert ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(i_chainIndex)];
  }
}
