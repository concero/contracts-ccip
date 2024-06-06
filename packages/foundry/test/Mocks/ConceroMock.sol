// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Concero} from "contracts/Concero.sol";

contract ConceroMock is Concero {

    constructor(
            address _functionsRouter,
            uint64 _donHostedSecretsVersion,
            bytes32 _donId,
            uint8 _donHostedSecretsSlotId,
            uint64 _subscriptionId,
            uint64 _chainSelector,
            uint _chainIndex,
            address _link,
            address _ccipRouter,
            address _dexSwap,
            Concero.JsCodeHashSum memory jsCodeHashSum
    ) Concero(
            _functionsRouter,
            _donHostedSecretsVersion,
            _donId,
            _donHostedSecretsSlotId,
            _subscriptionId,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            jsCodeHashSum
    ){}

    function externalFulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) external {
        fulfillRequest(requestId, response, err);
    }

    function getBnmToken() public pure returns (CCIPToken){
        return CCIPToken.bnm;
    }

}
