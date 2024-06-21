// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Concero} from "contracts/Concero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";

contract ConceroMock is Concero {

    constructor(
            Storage.FunctionsVariables memory _variables,
            uint64 _chainSelector,
            uint _chainIndex,
            address _link,
            address _ccipRouter,
            Concero.JsCodeHashSum memory jsCodeHashSum,
            bytes32 _ethersHashSum,
            address _dexSwap,
            address _pool,
            address _proxy
    ) Concero(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            jsCodeHashSum,
            _ethersHashSum,
            _dexSwap,
            _pool,
            _proxy
    ){}

    function externalFulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) external {
        fulfillRequest(requestId, response, err);
    }

    function getBnmToken() public pure returns (CCIPToken){
        return CCIPToken.bnm;
    }

}
