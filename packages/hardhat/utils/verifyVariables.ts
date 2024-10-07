import fs from "fs";
import path from "path";
import { task } from "hardhat/config";

/**
 * Retrieves all .sol files from the specified directory.
 * @param {string} dir - The directory path.
 * @returns {Promise<string[]>} - An array of .sol file paths.
 */
const getSolFiles = async dir => {
  const files = await fs.promises.readdir(dir);
  return files.filter(file => path.extname(file) === ".sol").map(file => path.join(dir, file));
};

/**
 * Processes a single Solidity file to check for mismatches in production values.
 * @param {string} filePath - The path to the .sol file.
 */
const processSolFile = async filePath => {
  const content = await fs.promises.readFile(filePath, "utf8");
  const contentLines = content.split("\n");

  const comments = extractChangeInProductionComments(contentLines);

  comments.forEach(({ lineNumber, expectedValue }) => {
    const variableLine = findVariableAfterLine(contentLines, lineNumber);
    if (variableLine) {
      const { variableName, currentValue } = parseVariableDeclaration(variableLine);
      if (variableName && currentValue !== null) {
        compareValues(variableName, currentValue, expectedValue);
      } else {
        console.warn(
          `Could not parse variable declaration after CHANGE-IN-PRODUCTION-TO at line ${lineNumber + 1} in ${filePath}`,
        );
      }
    } else {
      console.warn(
        `No variable declaration found after CHANGE-IN-PRODUCTION-TO at line ${lineNumber + 1} in ${filePath}`,
      );
    }
  });
};

/**
 * Extracts CHANGE-IN-PRODUCTION-TO comments from the content lines.
 * @param {string[]} contentLines - The content split into lines.
 * @returns {Array} - An array of comment objects with lineNumber and expectedValue.
 */
const extractChangeInProductionComments = contentLines => {
  const regex = /\/\*CHANGE-IN-PRODUCTION-TO-(.+?)\*\//;
  const comments = [];

  contentLines.forEach((line, index) => {
    const match = line.match(regex);
    if (match) {
      const expectedValue = match[1].trim();
      comments.push({ lineNumber: index, expectedValue });
    }
  });

  return comments;
};

/**
 * Finds the variable declaration after a specific line number.
 * @param {string[]} contentLines - The content split into lines.
 * @param {number} startLine - The line number to start searching from.
 * @returns {string|null} - The variable declaration line or null if not found.
 */
const findVariableAfterLine = (contentLines, startLine) => {
  for (let i = startLine + 1; i < contentLines.length; i++) {
    const line = contentLines[i].trim();
    if (line && !line.startsWith("//") && !line.startsWith("/*")) {
      return line;
    }
  }
  return null;
};

/**
 * Parses a variable declaration line to extract the variable name and its value.
 * @param {string} line - The line containing the variable declaration.
 * @returns {Object} - An object with variableName and currentValue.
 */
const parseVariableDeclaration = line => {
  // Match patterns like:
  // type [visibility] [constant] variableName = value;
  const regex = /(?:\w+\s+)*(?:\w+\s+)*(?:\w+\s+)?(\w+)\s*=\s*(.+?);/;
  const match = line.match(regex);
  if (match) {
    const variableName = match[1];
    let currentValue = match[2].trim();
    // Remove wrapping quotes from strings
    currentValue = currentValue.replace(/^['"`](.*)['"`]$/, "$1");
    return { variableName, currentValue };
  }
  return { variableName: null, currentValue: null };
};

/**
 * Compares the current and expected values of a variable and logs a warning if they don't match.
 * @param {string} variableName - The name of the variable.
 * @param {string} currentValue - The current value of the variable.
 * @param {string} expectedValue - The expected value from the comment.
 */

const yellow = "\u001b[33m";
const reset = "\u001b[0m";

const compareValues = (variableName, currentValue, expectedValue) => {
  const cleanExpected = expectedValue.replace(/^['"`](.*)['"`]$/, "$1");
  if (currentValue !== cleanExpected) {
    console.warn(
      `Variable ${yellow}${variableName}${reset} is set to ${yellow}${currentValue}${reset}, expected ${yellow}${cleanExpected}${reset} for production.`,
    );
  }
};

/**
 * Main function to initiate the script.
 */
const verifyVariables = async contractsDir => {
  try {
    const solFiles = await getSolFiles(contractsDir);
    for (const file of solFiles) {
      await processSolFile(file);
    }
  } catch (error) {
    console.error(`Error processing files: ${error.message}`);
  }
};

task("verify-variables", "Verifies if variables are set to production values").setAction(async () => {
  await verifyVariables("./contracts");
});

export default verifyVariables;
