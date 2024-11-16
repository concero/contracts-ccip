import { task } from "hardhat/config";
import axios from "axios";
import { conceroNetworks } from "../../constants";
import { log } from "../../utils";

const request = {
  jsonrpc: "2.0",
  method: "eth_call",
  params: [
    {
      from: "",
      to: "",
      gas: "",
      gasPrice: "",
      value: "",
      data: "",
    },
    "latest",
  ],
  id: 1,
};

export async function checkRpcStatus() {
  for (const [name, chain] of Object.entries(conceroNetworks)) {
    const urls = chain.urls;

    if (!urls || urls.length === 0) {
      log(`\nRPCs healthcheck for network:`, "checkRPCStatus", name);
      console.table([{ URL: "N/A", Status: "No URLs provided" }]);
      continue;
    }

    const results = await Promise.all(
      urls.map(async url => {
        try {
          const response = await axios.post(url, request);

          const parsedUrl = new URL(url);
          const shortenedUrl = parsedUrl.origin + "/";

          if (response.status === 200) {
            return { URL: shortenedUrl, Status: "OK" };
          } else {
            return { URL: shortenedUrl, Status: `Error: ${response.status}` };
          }
        } catch (error) {
          const parsedUrl = new URL(url);
          const shortenedUrl = parsedUrl.origin + "/";

          return { URL: shortenedUrl, Status: `Error: ${error.message}` };
        }
      }),
    );

    log(`RPCs healthcheck`, "checkRPCStatus", name);
    console.table(results);
  }
}

task("check-rpc-status", "Outputs a table of RPC URLs with their statuses").setAction(async (taskArgs, hre) => {
  await checkRpcStatus();
});

export default {};
