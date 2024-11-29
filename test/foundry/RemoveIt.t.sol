import "hardhat/console.sol";

contract RemoveIt {
    function test_removeIt() public {
        //        bytes
        //            memory dataToDecode = hex"000000000000000000000000dddddb8a8e41c194ac6542a0ad7ba663a72741e000000000000000000000000000000000000000000000000000000000000be59fffe1dfff1e01001e20001e03000b3c499c542cef5e3811e1192ce70d8cc03d5c3359001c91ce91000b0d500b1d8e8ef31e21c99d1db9a6444d3adf12700017eef32a1f18bad0d00017edc2d4941db384a1001ee0001e80000be592427a0aece92de3edee1f18e0157c05861564001d01f4003b67489f29";
        //
        //        (address receiver, uint256 amount, bytes memory compressedDstSwapData) = abi.decode(
        //            dataToDecode,
        //            (address, uint256, bytes)
        //        );
        //        console.log("receiver: %s", receiver);
        //        console.log("amount: %s", amount);

        uint256 amount = 1000000000000000000;
        address receiver = 0xddDd5f804B9D293dce8819d232e8D76381605a62;
        //        bytes
        //            memory data = hex"1dfff1e01001e20001e03000b3c499c542cef5e3811e1192ce70d8cc03d5c3359001c91ce91000bd500b1d8e8ef31e21c99d1db9a6444d3adf12700017eef32a1f18bad0d00017edc2d4941db384a1001ee0001e80000be592427a0aece92de3edee1f18e0157c05861564001d01f4003b67489f29";

        bytes memory data = new bytes(3);
        data[0] = 0x01;
        data[1] = 0x02;
        data[2] = 0x03;
        console.logBytes(data);

        bytes memory res = abi.encode(data, 8);
        console.logBytes(res);
    }
}
