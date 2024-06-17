// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import {IConceroPool} from "./Interfaces/IConceroPool.sol";

error ConceroAutomation_CallerNotAllowed(address caller);

/**
 * @dev Example contract, use the Forwarder as needed for additional security.
 * @notice important to implement {AutomationCompatibleInterface}
 */
contract ConceroAutomation is AutomationCompatibleInterface, Ownable {
  
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice variable to store the Concero Functions Contract
  address private immutable i_conceroFunctions;

  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  ///@notice variable to store the Concero Pool address
  address private s_conceroPool;
  ///@notice variable to store the automation keeper address
  address public s_keeperAddress;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array to store the withdraw requests of users
  IConceroPool.WithdrawRequests[] s_pendingWithdrawRequestsCLA;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a new request is added
  event ConceroAutomation_RequestAdded(IConceroPool.WithdrawRequests request);
  ///@notice event emitted when the Pool Address is updated
  event ConceroAutomation_PoolAddressUpdated(address pool);
  ///@notice event emitted when the Keeper Address is updated
  event ConceroAutomation_KeeperAddressUpdated(address keeperAddress);

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
    constructor(address _functions, address _owner) Ownable(_owner){
        i_conceroFunctions = _functions;
    }

    function setPoolAddress(address _pool) external onlyOwner{
        s_conceroPool = _pool;

        emit ConceroAutomation_PoolAddressUpdated(_pool);
    }

    function addPendingWithdrawal(IConceroPool.WithdrawRequests memory request) external {
        if(s_conceroPool != msg.sender) revert ConceroAutomation_CallerNotAllowed(msg.sender);

        s_pendingWithdrawRequestsCLA.push(request);

        emit ConceroAutomation_RequestAdded(request);
    }

    function checkUpkeep( bytes calldata /* checkData */) external view override returns (bool _upkeepNeeded, bytes memory _performData) {
        if(msg.sender != s_keeperAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);
        uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

        for(uint256 i; i < requestsNumber; ++i){
            if(block.timestamp > s_pendingWithdrawRequestsCLA[i].deadline){
                
                _performData = abi.encode(
                    s_pendingWithdrawRequestsCLA[i].sender, //address
                    s_pendingWithdrawRequestsCLA[i].amount, //uint256
                    s_pendingWithdrawRequestsCLA[i].token //address
                );
                _upkeepNeeded = true;
            }
        }
    }

    function performUpkeep(bytes calldata _performData) external override {
        if(msg.sender != s_keeperAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);

        //i_conceroFunctions.sendRequest(_performData);
    }
    
    function setKeeperAddress(address _keeperAddress) external onlyOwner {
        s_keeperAddress = _keeperAddress;

        emit ConceroAutomation_KeeperAddressUpdated(_keeperAddress);
    }
}
