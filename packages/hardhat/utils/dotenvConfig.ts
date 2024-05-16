import * as dotenv from "dotenv";
import fs from "fs";

const ENV_FILES = [".env", ".env.clf", ".env.clccip", ".env.tokens", ".env.deployments"];

/**
 * Configures the dotenv with paths relative to a base directory.
 * @param {string} [basePath='../../../'] - The base path where .env files are located. Defaults to '../../'.
 */
function configureDotEnv(basePath = "../../") {
  const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;

  ENV_FILES.forEach(file => {
    dotenv.config({ path: `${normalizedBasePath}${file}` });
  });
}
configureDotEnv();

export function reloadDotEnv(basePath = "../../") {
  const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;

  ENV_FILES.forEach(file => {
    const fullPath = `${normalizedBasePath}${file}`;
    const currentEnv = dotenv.parse(fs.readFileSync(fullPath));

    Object.keys(currentEnv).forEach(key => {
      delete process.env[key];
    });

    dotenv.config({ path: fullPath });
  });
}

export default configureDotEnv;
