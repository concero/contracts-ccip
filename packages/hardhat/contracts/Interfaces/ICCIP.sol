pragma solidity 0.8.20;

interface ICCIP {
    ///@notice CCIP transaction types
    enum CcipTxType {
        deposit,
        bridge,
        withdraw,
        liquidityRebalancing
    }

    ///@notice CCIP transaction data ie infraType with txIds, recipients, amounts
    struct CcipTxData {
        CcipTxType ccipTxType;
        bytes data;
    }
}
