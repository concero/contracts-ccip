import { readFileSync, writeFileSync } from "fs";
import path from "path";
import log from "./log";

/**
 * Update an environment variable in the .env file
 * @param key The key of the environment variable to update
 * @param newValue The new value of the environment variable
 * @param envFileName The name of the .env file to update
 * usage: // updateEnvVariable("CLF_DON_SECRETS_VERSION_SEPOLIA", "1712841283", "../../../.env.clf");
 */
type EnvFileName = "cla" | "clf" | "ccip" | "deployments.mainnet" | "deployments.testnet" | "apikeys" | "tokens";

function updateEnvVariable(key: string, newValue: string, envFileName: EnvFileName) {
  const filePath = path.join(__dirname, `../../../.env.${envFileName}`);
  if (!filePath) throw new Error(`File not found: ${filePath}`);

  const envContents = readFileSync(filePath, "utf8");
  let lines = envContents.split(/\r?\n/);

  if (!lines.some(line => line.startsWith(`${key}=`))) {
    log(`Key ${key} not found in .env file. Adding to ${filePath}`, "updateEnvVariable");
    lines.push(`${key}=${newValue}`);
  }

  const newLines = lines.map(line => {
    let [currentKey, currentValue] = line.split("=");
    if (currentKey === key) {
      return `${key}=${newValue}`;
    }
    return line;
  });

  writeFileSync(filePath, newLines.join("\n"));
  process.env[key] = newValue;
}

export default updateEnvVariable;
