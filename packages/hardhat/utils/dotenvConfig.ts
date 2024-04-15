import * as dotenv from "dotenv";

/**
 * Configures the dotenv with paths relative to a base directory.
 * @param {string} [basePath='../../../'] - The base path where .env files are located. Defaults to '../../'.
 */
function configureDotEnv(basePath = "../../") {
  // Normalize the base path to ensure it ends with a '/'
  const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;
  // const absolutepath = require("path").resolve(`${normalizedBasePath}.env`);

  // Configure dotenv for each specific file
  dotenv.config({ path: `${normalizedBasePath}.env` });
  dotenv.config({ path: `${normalizedBasePath}.env.clf` });
  dotenv.config({ path: `${normalizedBasePath}.env.clccip` });
  dotenv.config({ path: `${normalizedBasePath}.env.tokens` });
}
configureDotEnv();

export default configureDotEnv;
