// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {InfraStorage} from "./InfraStorage.sol";

contract InfraStorageSetters is InfraStorage {
    ///////////////////////////////
    /////////////ERROR/////////////
    ///////////////////////////////

    ///@notice error emitted when the input is the address(0)
    error StorageSetters_InvalidAddress();
    ///@notice error emitted when a non-owner address call access controlled functions
    error StorageSetters_CallableOnlyByOwner(address msgSender, address owner);

    ///////////////
    ///IMMUTABLE///
    ///////////////
    address internal immutable i_owner;

    constructor(address _initialOwner) {
        i_owner = _initialOwner;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert StorageSetters_CallableOnlyByOwner(msg.sender, i_owner);
        _;
    }

    ///////////////////////////
    /// FUNCTIONS VARIABLES ///
    ///////////////////////////

    /**
     * @notice Function to update Chainlink Functions fees
     * @param _chainSelector Chain Identifier
     * @param feeAmount fee amount
     * @dev arb default fee: 3478487238524512106 == 4000000000000000; // 0.004 link
     * @dev base default fee: 10344971235874465080 == 1847290640394088; // 0.0018 link
     * @dev opt default fee: 5224473277236331295 == 2000000000000000; // 0.002 link
     */
    function setClfPremiumFees(
        uint64 _chainSelector,
        uint256 feeAmount
    ) external payable onlyOwner {
        //@audit we must limit this amount. If we don't, it Will trigger red flags in audits.
        uint256 previousValue = clfPremiumFees[_chainSelector];
        clfPremiumFees[_chainSelector] = feeAmount;
    }

    /**
     * @notice Function to update Secret Version
     * @param _version the new Secret Version
     */
    function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
        uint64 previousValue = s_donHostedSecretsVersion;
        s_donHostedSecretsVersion = _version;
    }

    /**
     * @notice Function to update the CLF slot id
     * @param _donHostedSecretsSlotId the new slot id
     */
    function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
        uint8 previousValue = s_donHostedSecretsSlotId;
        s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
    }

    /**
     * @notice Function to updated the Dst Hash Sum
     * @param _hashSum the new hash sum
     */
    function setDstJsHashSum(bytes32 _hashSum) external onlyOwner {
        bytes32 previousValue = s_dstJsHashSum;
        s_dstJsHashSum = _hashSum;
    }

    /**
     * @notice Function to updated the Src Hash sum
     * @param _hashSum the new hash sum
     */
    function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
        bytes32 previousValue = s_srcJsHashSum;
        s_srcJsHashSum = _hashSum;
    }

    /**
     * @notice Function to set the Ether HashSum
     * @param _hashSum the new hash sum
     */
    function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
        bytes32 previousValue = s_ethersHashSum;
        s_ethersHashSum = _hashSum;
    }

    /////////////////////////
    /// CONTRACT ADDRESSES///
    /////////////////////////
    /**
     * @notice Function to set a Cross-chain Concero contract
     * @param _chainSelector The chain selector of the chain
     * @param _conceroContract the address of the contract
     */
    function setConceroContract(
        uint64 _chainSelector,
        address _conceroContract
    ) external onlyOwner {
        if (_conceroContract == address(0)) revert StorageSetters_InvalidAddress();
        s_conceroContracts[_chainSelector] = _conceroContract;
    }

    /**
     * @notice function to set the address of a Cross-chain pool
     * @param _chainSelector The chain selector of the chain
     * @param _pool the address of the Pool
     */
    function setDstConceroPool(uint64 _chainSelector, address _pool) external payable onlyOwner {
        if (_pool == address(0)) revert StorageSetters_InvalidAddress();
        s_poolReceiver[_chainSelector] = _pool;
    }

    /**
     * @notice function to manage DEX routers addresses
     * @param _router the address of the router
     * @param _isApproved 1 == Approved | Any other value is not Approved.
     */
    function setDexRouterAddress(address _router, bool _isApproved) external payable onlyOwner {
        if (_router == address(0)) revert StorageSetters_InvalidAddress();
        s_routerAllowed[_router] = _isApproved;
    }
}
