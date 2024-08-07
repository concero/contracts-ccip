/*
Replaces environment variables in a file and saves the result to a dist folder.
run with: yarn hardhat clf-build-script --path ./CLFScripts/DST.js
 */

import { task, types } from "hardhat/config";
import log, { err } from "../../utils/log";

export const pathToScript = [__dirname, "../", "CLFScripts"];
const fs = require("fs");
const path = require("path");

function checkFileAccessibility(filePath) {
  if (!fs.existsSync(filePath)) {
    err(`The file ${filePath} does not exist.`, "checkFileAccessibility");
    process.exit(1);
  }
}

/* replaces any strings of the form ${VAR_NAME} with the value of the environment variable VAR_NAME */
function replaceEnvironmentVariables(content) {
  let missingVariable = false;
  const updatedContent = content.replace(/'\${(.*?)}'/g, (match, variable) => {
    const value = process.env[variable];

    if (value === undefined) {
      err(`Environment variable ${variable} is missing.`, "replaceEnvironmentVariables");
      process.exit(1);
    }
    return `'${value}'`;
  });

  if (missingVariable) {
    err("One or more environment variables are missing.", "replaceEnvironmentVariables");
    process.exit(1);
  }
  return updatedContent;
}

function saveProcessedFile(content, outputPath, scriptType: string) {
  const outputDir = path.join(...pathToScript, `dist/${scriptType}`);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }
  const outputFile = path.join(outputDir, path.basename(outputPath));
  fs.writeFileSync(outputFile, content, "utf8");
  log(`Saved to ${outputFile}`, "saveProcessedFile");
}

function cleanupFile(content) {
  const marker = "/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/";
  const index = content.indexOf(marker);
  if (index !== -1) content = content.substring(index + marker.length);
  return content
    .replace(/^\s*\/\/.*$/gm, "") // Remove single-line comments that might be indented
    .replace(/\/\*[\s\S]*?\*\//g, "") // Remove multi-line comments
    .replace(/^\s*[\r\n]/gm, ""); // Remove empty lines
}

function minifyFile(content) {
  return content
    .replace(/\n/g, " ") // Remove newlines
    .replace(/\t/g, " ") // Remove tabs
    .replace(/\s\s+/g, " "); // Replace multiple spaces with a single space
}

export function buildScript(fileToBuild: string) {
  if (!fileToBuild) {
    err("Path to Functions script file is required.", "buildScript");
    return;
  }

  checkFileAccessibility(fileToBuild);

  try {
    let fileContent = fs.readFileSync(fileToBuild, "utf8");
    fileContent = replaceEnvironmentVariables(fileContent);
    let cleanedUpFile = cleanupFile(fileContent);
    let minifiedFile = minifyFile(cleanedUpFile);
    let scriptType = "pool";

    if (fileToBuild.split("/").includes("infra")) {
      scriptType = "infra";
    }

    saveProcessedFile(cleanedUpFile, fileToBuild, scriptType);
    saveProcessedFile(minifiedFile, fileToBuild.replace(".js", ".min.js"), scriptType);
  } catch (error) {
    err(`Error processing file ${fileToBuild}: ${error}`, "buildScript");
    process.exit(1);
  }
}

// run with: yarn hardhat clf-script-build --file DST.js
task("clf-script-build", "Builds the JavaScript source code")
  .addFlag("all", "Build all scripts")
  .addOptionalParam("file", "Path to Functions script file", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    if (taskArgs.all) {
      const paths = ["src/infra", "src/pool"];

      paths.forEach((_path: string) => {
        const files = fs.readdirSync(path.join(...pathToScript, _path));

        files.forEach((file: string) => {
          if (file.endsWith(".js")) {
            const fileToBuild = path.join(...pathToScript, _path, file);
            buildScript(fileToBuild);
          }
        });
      });

      return;
    }
    if (taskArgs.file) {
      const fileToBuild = path.join(...pathToScript, "src", taskArgs.file);
      buildScript(fileToBuild);
    } else {
      console.error("No file specified.");
      process.exit(1);
    }
  });
export default {};
