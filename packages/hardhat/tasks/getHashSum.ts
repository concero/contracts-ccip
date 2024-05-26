import { task } from "hardhat/config";
import secrets from "../constants/CLFSecrets";
import getHashSum from "../utils/getHashSum";

task("list-hashsums", "A test script").setAction(async taskArgs => {
  console.log("SRC:", getHashSum(secrets.SRC_JS));
  console.log("DST:", getHashSum(secrets.DST_JS));
});

export default {};
