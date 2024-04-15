import * as dotenv from "dotenv";

function configureDotEnv() {
  dotenv.config({ path: "../../../.env" });
  dotenv.config({ path: "../../../.env.clf" });
  dotenv.config({ path: "../../../.env.clccip" });
  dotenv.config({ path: "../../../.env.tokens" });
}

export { configureDotEnv };
