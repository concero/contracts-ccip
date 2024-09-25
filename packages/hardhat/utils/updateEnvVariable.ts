import { readFileSync, writeFileSync } from "fs";
import path from "path";
import log from "./log";
import { envPrefixes, networkEnvKeys } from "../constants";
import { CNetworkNames } from "../types/CNetwork";
import { EnvFileName, EnvPrefixes } from "../types/deploymentVariables";

export function updateEnvVariable(key: string, newValue: string, envFileName: EnvFileName) {
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

export function updateEnvAddress(
  prefix: keyof EnvPrefixes,
  networkPostfix?: CNetworkNames | string,
  newValue: string,
  envFileName: EnvFileName,
): void {
  const searchKey = networkPostfix ? `${envPrefixes[prefix]}_${networkEnvKeys[networkPostfix]}` : envPrefixes[prefix];

  updateEnvVariable(searchKey, newValue, envFileName);
}

export default updateEnvVariable;
