//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {IStorage} from "../Interfaces/IStorage.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when bridge data is empty
error Storage_InvalidBridgeData();
///@notice error emitted when the chosen token is not allowed
error Storage_TokenTypeOutOfBounds();
///@notice error emitted when the chain index is incorrect
error Storage_ChainIndexOutOfBounds();
///@notice error emitted when the caller is not the messenger
error Storage_NotMessenger(address caller);
///@notice error emitted when the input is the address(0)
error Storage_InvalidAddress();
///@notice error emitted when the chain selector input is invalid
error Storage_ChainNotAllowed(uint64 chainSelector);
///@notice error emitted when the caller is not the owner
error NotContractOwner();

abstract contract Storage is IStorage {
  ///////////////
  ///VARIABLES///
  ///////////////
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 internal s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_srcJsHashSum;
  ///@notice variable to store the Chainlink Function Destination Hashsum
  bytes32 internal s_dstJsHashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;
  ///@notice Variable to store the Link to USDC latest rate
  uint256 public s_latestLinkUsdcRate;
  ///@notice Variable to store the Native to USDC latest rate
  uint256 public s_latestNativeUsdcRate;
  ///@notice Variable to store the Link to Native latest rate
  uint256 public s_latestLinkNativeRate;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  address immutable i_owner;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;
  ///@notice Removing magic numbers from calculations
  uint16 internal constant CONCERO_FEE_FACTOR = 1000;

  /////////////
  ///STORAGE///
  /////////////

  ///@notice Concero: Mapping to keep track of CLF fees for different chains
  mapping(uint64 => uint256) public clfPremiumFees;
  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerAddresses;
  ///@notice DexSwap: mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) internal s_routerAllowed;

  ///@notice Functions: Mapping to keep track of Concero.sol contracts to send cross-chain Chainlink Functions messages
  mapping(uint64 chainSelector => address conceroContract) internal s_conceroContracts;
  ///@notice Functions: Mapping to keep track of cross-chain transactions
  mapping(bytes32 => Transaction) public s_transactions;
  ///@notice Functions: Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 => Request) public s_requests;
  ///@notice Functions: Mapping to keep track of cross-chain gas prices
  mapping(uint64 chainSelector => uint256 lasGasPrice) public s_lastGasPrices;

  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolReceiver;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event Storage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when the Messenger address is updated
  event Storage_MessengerUpdated(address indexed walletAddress, uint256 status);
  ///@notice event emitted when the router address is approved
  event Storage_NewRouterAdded(address router, uint256 isAllowed);
  ///@notice Concero CCIP: event emitted when the Chainlink Function Fee is updated
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);
  ///@notice Concero Functions: emitted when the concero pool address is updated
  event ConceroPoolAddressUpdated(address previousAddress, address pool);
  ///@notice Concero Functions: emitted when the secret version of Chainlink Function Don is updated
  event DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  ///@notice Concero Functions: emitted when the slot ID of Chainlink Function is updated
  event DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot);
  ///@notice Concero Functions: emitted when the source JS code of Chainlink Function is updated
  event SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);
  ///@notice Concero Functions: emitted when the destination JS code of Chainlink Function is updated
  event DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);
  ///@notice Concero Functions: emitted when the address for the Concero Contract is updated
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  ///@notice Concero Functions: emitted when the Ethers HashSum is updated
  event EthersHashSumUpdated(bytes32 previousValue, bytes32 hashSum);

  ///////////////
  ///MODIFIERS///
  ///////////////
  //@audit Unused in the moment
  // modifier validateSwapAndBridgeData(
  //   BridgeData calldata _bridgeData,
  //   IDexSwap.SwapData[] calldata _srcSwapData,
  //   uint64 _chainIndex
  // ) {
  //   address swapDataToToken = _srcSwapData[_srcSwapData.length - 1].toToken;

  //   if (swapDataToToken == getToken(_bridgeData.tokenType, s_chainIndex)) {
  //     revert Storage_InvalidBridgeData();
  //   }
  //   _;
  // }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (s_messengerAddresses[msg.sender] != APPROVED) revert Storage_NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolReceiver[_chainSelector] == address(0)) revert Storage_ChainNotAllowed(_chainSelector);
    _;
  }

  modifier onlyOwner() {
    if (msg.sender != i_owner) revert NotContractOwner();
    _;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////
  constructor(address _owner) {
    i_owner = _owner;
  }

  //////////////
  ///EXTERNAL///
  //////////////
  /**
   * @notice Function to update Concero Messenger Addresses
   * @param _walletAddress the messenger address
   * @param _approved 1 == Approved | Any other value disapproved
   */
  //@changed
  function setConceroMessenger(address _walletAddress, uint256 _approved) external onlyOwner {
    if (_walletAddress == address(0)) revert Storage_InvalidAddress();

    s_messengerAddresses[_walletAddress] = _approved;

    emit Storage_MessengerUpdated(_walletAddress, _approved);
  }

  /**
   * @notice function to manage DEX routers addresses
   * @param _router the address of the router
   * @param _isApproved 1 == Approved | Any other value is not Approved.
   */
  function manageRouterAddress(address _router, uint256 _isApproved) external payable onlyOwner {
    s_routerAllowed[_router] = _isApproved;

    emit Storage_NewRouterAdded(_router, _isApproved);
  }

  /**
   * @notice Function to set the Chainlink Functions Fee
   * @param _chainSelector The blockchain chains selector to update the variable
   * @param feeAmount The total amount of fees charged.
   */
  function setClfPremiumFees(uint64 _chainSelector, uint256 feeAmount) external onlyOwner {
    //@audit we must limit this amount. If we don't, it Will trigger red flags in audits.
    uint256 previousValue = clfPremiumFees[_chainSelector];
    clfPremiumFees[_chainSelector] = feeAmount;

    emit CLFPremiumFeeUpdated(_chainSelector, previousValue, feeAmount);
  }

  /**
   * @notice function to set the Concero Contract Address that Chainlink Functions will use
   * @param _chainSelector the blockchain selector
   * @param _conceroContract the address of the destination contract
   * @dev this functions was used inside of ConceroFunctions
   */
  function setConceroContract(uint64 _chainSelector, address _conceroContract) external onlyOwner {
    s_conceroContracts[_chainSelector] = _conceroContract;

    emit ConceroContractUpdated(_chainSelector, _conceroContract);
  }

  /**
   * @notice Function to set the Don Secrects Version from Chainlink Functions
   * @param _version the version
   * @dev this functions was used inside of ConceroFunctions
   */
  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    uint64 previousValue = s_donHostedSecretsVersion;

    s_donHostedSecretsVersion = _version;

    emit DonSecretVersionUpdated(previousValue, _version);
  }

  /**
   * @notice Function to set the Don Secrects Slot ID from Chainlink Functions
   * @param _donHostedSecretsSlotId the slot number
   * @dev this functions was used inside of ConceroFunctions
   */
  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
    uint8 previousValue = s_donHostedSecretsSlotId;

    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;

    emit DonSlotIdUpdated(previousValue, _donHostedSecretsSlotId);
  }

  /**
   * @notice Function to set the Destination JS code for Chainlink Functions
   * @param _hashSum the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setDstJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_dstJsHashSum = _hashSum;

    emit DestinationJsHashSumUpdated(previousValue, _hashSum);
  }

  /**
   * @notice Function to set the Source JS code for Chainlink Functions
   * @param _hashSum  the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_srcJsHashSum = _hashSum;

    emit SourceJsHashSumUpdated(previousValue, _hashSum);
  }

  /**
   * @notice Function to set the Ethers JS code for Chainlink Functions
   * @param _hashSum the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_ethersHashSum;
    s_ethersHashSum = _hashSum;
    emit EthersHashSumUpdated(previousValue, _hashSum);
  }

  /////////////////
  ///VIEW & PURE///
  /////////////////
  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(CCIPToken token, Chain _chainIndex) internal pure returns (address) {
    address[3][2] memory tokens;

    //@audit use the actual chain id and not 0 1 2
    // Initialize BNM addresses
    tokens[0][0] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[0][1] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[0][2] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt

    // Initialize USDC addresses
    tokens[1][0] = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // arb
    tokens[1][1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // base
    tokens[1][2] = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7; // opt

    if (uint256(token) > tokens.length) revert Storage_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert Storage_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }
}
