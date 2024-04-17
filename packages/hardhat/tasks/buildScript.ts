/*
Replaces environment variables in a file and saves the result to a dist folder.
run with: bunx hardhat functions-build-script --path ./CLFScripts/DST.js
 */

import { task, types } from "hardhat/config";

const fs = require("fs");
const path = require("path");

function checkFileAccessibility(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`The file ${filePath} does not exist.`);
    process.exit(1);
  }
}

/* replaces any strings of the form ${VAR_NAME} with the value of the environment variable VAR_NAME */
function replaceEnvironmentVariables(content) {
  let missingVariable = false;
  const updatedContent = content.replace(/'\${(.*?)}'/g, (match, variable) => {
    const value = process.env[variable];

    if (value === undefined) {
      console.error(`Environment variable ${variable} is missing.`);
      process.exit(1);
    }
    return `'${value}'`;
  });

  if (missingVariable) {
    console.error("One or more environment variables are missing.");
    process.exit(1);
  }
  return updatedContent;
}

function saveProcessedFile(content, outputPath) {
  const outputDir = path.join(__dirname, "CLFScripts", "dist");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }
  const outputFile = path.join(outputDir, path.basename(outputPath));
  fs.writeFileSync(outputFile, content, "utf8");
  console.log(`Saved to ${outputFile}`);
}

function cleanupFile(content) {
  const marker = "/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/";
  const index = content.indexOf(marker);
  if (index !== -1) content = content.substring(index + marker.length);
  return content
    .replace(/^\/\/.*/gm, "") // Remove single-line comments
    .replace(/\/\*[\s\S]*?\*\//g, "") // Remove multi-line comments
    .replace(/^\s*[\r\n]/gm, ""); // Remove empty lines
}

function minifyFile(content) {
  return content
    .replace(/\n/g, " ") // Remove newlines
    .replace(/\t/g, " ") // Remove tabs
    .replace(/\s\s+/g, " "); // Replace multiple spaces with a single space
}

// run with: bunx hardhat functions-build-script --path ./CLFScripts/DST.js
task("functions-build-script", "Builds the JavaScript source code")
  .addParam("path", "Path to Functions script file", undefined, types.string)
  .setAction(async (taskArgs, hre) => {
    if (!taskArgs.path) return console.error("Path to Functions script file is required.");
    const fileToBuild = path.join(__dirname, taskArgs.path);
    checkFileAccessibility(fileToBuild);

    try {
      let fileContent = fs.readFileSync(fileToBuild, "utf8");
      fileContent = replaceEnvironmentVariables(fileContent);
      fileContent = cleanupFile(fileContent);
      let minifiedFile = minifyFile(fileContent);

      saveProcessedFile(fileContent, fileToBuild);
      saveProcessedFile(minifiedFile, fileToBuild.replace(".js", ".min.js"));
    } catch (err) {
      console.error(`Error processing file ${fileToBuild}: ${err}`);
      process.exit(1);
    }
  });
export default {};
