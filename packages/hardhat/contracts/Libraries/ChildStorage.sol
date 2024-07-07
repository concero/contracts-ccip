//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ChildStorage {
  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 public s_loansInUse;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address conceroContract => uint256)) public s_contractsToReceiveFrom;
}
