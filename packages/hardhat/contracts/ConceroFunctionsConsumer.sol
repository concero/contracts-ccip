// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract ConceroFunctionsConsumer is FunctionsClient, ConfirmedOwner {
    bytes32 private donId;
    bytes32 private lastRequestId;
    using FunctionsRequest for FunctionsRequest.Request;

    string jsCode = "console.log('jsCode')";

    error UnexpectedRequestID(bytes32);

    event Response(bytes32, string, bytes, bytes);

    constructor(address _router, bytes32 _donId)
    FunctionsClient(_router)
    ConfirmedOwner(msg.sender)
    {
        donId = _donId;
    }

    function sendRequest(uint64 subscriptionId, string[] calldata args)
    external
    onlyOwner
    returns (bytes32)
    {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsCode);

        if (args.length > 0) {
            req.setArgs(args);
        }

        lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            300_000,
            donId
        );

        return lastRequestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }

        string memory character = string(response);

        emit Response(requestId, character, response, err);
    }
}
