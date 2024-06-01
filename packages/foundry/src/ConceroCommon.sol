// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IConceroCommon} from "./IConcero.sol";

import {Storage} from "./Libraries/Storage.sol";

contract ConceroCommon is ConfirmedOwner, IConceroCommon, Storage {
  uint64 internal immutable CHAIN_SELECTOR;
  Chain internal immutable i_chainIndex;

  constructor(uint64 _chainSelector, uint _chainIndex) ConfirmedOwner(msg.sender) {
    CHAIN_SELECTOR = _chainSelector;
    i_chainIndex = Chain(_chainIndex);
  }

  function setConceroContract(uint64 _chainSelector, address _conceroContract) external onlyOwner {
    s_conceroContracts[_chainSelector] = _conceroContract;

    emit ConceroContractUpdated(_chainSelector, _conceroContract);
  }

  function setConceroMessenger(address _walletAddress) external onlyOwner {
    if (_walletAddress == address(0)) revert InvalidAddress();
    if (s_messengerContracts[_walletAddress] == true) revert AddressAlreadyAllowlisted();

    s_messengerContracts[_walletAddress] = true;

    emit MessengerUpdated(_walletAddress, true);
  }

  //@audit we can merge setConceroMessenger & removeConceroMessenger
  function removeConceroMessenger(address _walletAddress) external onlyOwner {
    if (_walletAddress == address(0)) revert InvalidAddress();
    if (s_messengerContracts[_walletAddress] == false) revert NotAllowlistedOrAlreadyRemoved();

    s_messengerContracts[_walletAddress] = false;

    emit MessengerUpdated(_walletAddress, true);
  }
}