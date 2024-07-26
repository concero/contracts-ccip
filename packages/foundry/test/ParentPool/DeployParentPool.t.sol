import {Script} from "../../lib/forge-std/src/Script.sol";
import {ParentPoolDeploy} from "../../script/ParentPoolDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployParentPool is Test {
    ConceroParentPool public pool;

    function deployParentPool() public {
        ParentPoolDeploy deployScript = new ParentPoolDeploy();
        pool = deployScript.run(
            address(0),
            address(0),
            bytes32(0),
            uint64(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(this)
        );
    }
}
