//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Storage} from "./Storage.sol";

contract StorageSetters is Storage {
  ///////////////////////////////
  /////////////ERROR/////////////
  ///////////////////////////////

  ///@notice error emitted when the input is the address(0)
  error Storage_InvalidAddress();
  error Storage_CallableOnlyByOwner(address msgSender, address owner);

  ///////////////
  ///CONSTANTS///
  ///////////////

  ///////////////
  ///IMMUTABLE///
  ///////////////
  address internal immutable i_owner;

  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  event DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  event DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot);
  event DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);
  event SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);
  event EthersHashSumUpdated(bytes32 previousValue, bytes32 hashSum);
  ///@notice event emitted when a new router address is added
  event Storage_NewRouterAdded(address router, uint256 isApproved);
  ///@notice event emitted a cross-chain Gas price is updated.
  event StorageSetters_LastGasPriceUpdated(uint64 chainSelector, uint256 feeAmount);
  ///@notice event emitted when the Link to Usdc rate is updated
  event StorageSetters_LinkUsdcRateUpdated(uint256 amount);
  ///@notice event emitted when the Native to Usdc rate is updated
  event StorageSetters_NativeUsdcRateUpdated(uint256 amount);
  ///@notice event emitted when the Link to Native rate is updated
  event StorageSetters_LinkNativeRateUpdated(uint256 amount);

  constructor(address _initialOwner) {
    i_owner = _initialOwner;
  }

  modifier onlyOwner() {
    if (msg.sender != i_owner) revert Storage_CallableOnlyByOwner(msg.sender, i_owner);
    _;
  }

  /**
   * @notice function to manage DEX routers addresses
   * @param _router the address of the router
   * @param _isApproved 1 == Approved | Any other value is not Approved.
   */
  function setDexRouterAddress(address _router, uint256 _isApproved) external payable onlyOwner {
    s_routerAllowed[_router] = _isApproved;
    emit Storage_NewRouterAdded(_router, _isApproved);
  }

  /**
   * @notice Function to update Chainlink Functions fees
   * @param _chainSelector Chain Identifier
   * @param feeAmount fee amount
   * @dev arb default fee: 3478487238524512106 == 4000000000000000; // 0.004 link
   * @dev base default fee: 10344971235874465080 == 1847290640394088; // 0.0018 link
   * @dev opt default fee: 5224473277236331295 == 2000000000000000; // 0.002 link
   */
  function setClfPremiumFees(uint64 _chainSelector, uint256 feeAmount) external payable onlyOwner {
    //@audit we must limit this amount. If we don't, it Will trigger red flags in audits.
    uint256 previousValue = clfPremiumFees[_chainSelector];
    clfPremiumFees[_chainSelector] = feeAmount;
    emit CLFPremiumFeeUpdated(_chainSelector, previousValue, feeAmount);
  }

  /**
   * @notice function to update Gas Prices Cross Chain
   * @param _chainSelector the chain Id
   * @param _gasPrice the cost of gas
   * @dev this function should be called only before the first transaction
  */
  function setLastGasPrices(uint64 _chainSelector, uint256 _gasPrice) external onlyOwner {
    s_lastGasPrices[_chainSelector] = _gasPrice;

    emit StorageSetters_LastGasPriceUpdated(_chainSelector, _gasPrice);
  }

  /**
   * @notice Function to update Link To USDC rate
   * @param _latestRate the latest rate
   * @dev this function should be called only before the first transaction
   */
  function setLatestLinkUsdcRate(uint256 _latestRate) external payable onlyOwner{
    s_latestLinkUsdcRate = _latestRate;
    
    emit StorageSetters_LinkUsdcRateUpdated(_latestRate);
  }

  /**
   * @notice Function to Update the Native to USDC rate
   * @param _latestRate the latest rate
   * @dev this function should be called only before the first transaction
   */
  function setLatestNativeUsdcRate(uint256 _latestRate) external payable onlyOwner{
    s_latestNativeUsdcRate = _latestRate;
    
    emit StorageSetters_NativeUsdcRateUpdated(_latestRate);
  }

  /**
   * Function to update the Link To Native rate
   * @param _latestRate the latest Rate
   * @dev this function should be called only before the first transaction
   * 
   */
  function setLatestLinkNativeRate(uint256 _latestRate) external payable onlyOwner{
    s_latestLinkNativeRate = _latestRate;
    
    emit StorageSetters_LinkNativeRateUpdated(_latestRate);
  }  

  function setConceroContract(uint64 _chainSelector, address _conceroContract) external onlyOwner {
    s_conceroContracts[_chainSelector] = _conceroContract;
    emit ConceroContractUpdated(_chainSelector, _conceroContract);
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    uint64 previousValue = s_donHostedSecretsVersion;
    s_donHostedSecretsVersion = _version;
    emit DonSecretVersionUpdated(previousValue, _version);
  }

  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
    uint8 previousValue = s_donHostedSecretsSlotId;
    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
    emit DonSlotIdUpdated(previousValue, _donHostedSecretsSlotId);
  }

  function setDstJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;
    s_dstJsHashSum = _hashSum;
    emit DestinationJsHashSumUpdated(previousValue, _hashSum);
  }

  function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_srcJsHashSum;
    s_srcJsHashSum = _hashSum;
    emit SourceJsHashSumUpdated(previousValue, _hashSum);
  }

  function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_ethersHashSum;
    s_ethersHashSum = _hashSum;
    emit EthersHashSumUpdated(previousValue, _hashSum);
  }

  function setDstConceroPool(uint64 _chainSelector, address _pool) external payable onlyOwner {
    s_poolReceiver[_chainSelector] = _pool;
  }

  // TODO: REMOVE IN PRODUCTION!!!
  function setLasGasPrices(uint64 _chainSelector, uint256 _lastGasPrice) external payable onlyOwner {
    s_lastGasPrices[_chainSelector] = _lastGasPrice;
  }
}
