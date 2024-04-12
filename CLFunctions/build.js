/*
Replaces environment variables in a file and saves the result to a dist folder.
 */

const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const scriptDir = path.resolve(__dirname);

// Setup environment configuration
function setupEnvironment(envPath) {
	dotenv.config({path: envPath});
	dotenv.config({path: envPath + '.chainlink'});
	dotenv.config({path: envPath + '.tokens'});
}

setupEnvironment(path.join(scriptDir, '../.env'));

// Handle command-line arguments
function parseArguments() {
	const args = process.argv.slice(2);
	if (args.length === 0) {
		console.error('Please specify a file to build');
		process.exit(1);
	}
	return args[0];
}

// Check if the file exists and is accessible
function checkFileAccessibility(filePath) {
	if (!fs.existsSync(filePath)) {
		console.error(`The file ${filePath} does not exist.`);
		process.exit(1);
	}
}

// Replace environment variables in the content, fail if any are missing
// replaces any strings of the form ${VAR_NAME} with the value of the environment variable VAR_NAME
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
		console.error('One or more environment variables are missing.');
		process.exit(1);
	}
	return updatedContent;
}

function saveProcessedFile(content, outputPath) {
	const outputDir = path.join(scriptDir, 'dist');
	if (!fs.existsSync(outputDir)) {
		fs.mkdirSync(outputDir);
	}
	const outputFile = path.join(outputDir, path.basename(outputPath));
	fs.writeFileSync(outputFile, content, 'utf8');
	console.log(`Saved to dist/${outputPath}`);
}

function minifyFile(content) {
	return (
		content
			// Remove single-line comments, only if they're in the beginning of the line
			.replace(/^\/\/.*/gm, '')
			// Remove multi-line comments
			.replace(/\/\*[\s\S]*?\*\//g, '')
			// Remove newlines
			.replace(/\n/g, ' ')
			// Remove tabs
			.replace(/\t/g, ' ')
			// Replace multiple spaces with a single space
			.replace(/\s\s+/g, ' ')
	);
}

function buildFile() {
	const fileToBuild = parseArguments();
	checkFileAccessibility(fileToBuild);

	try {
		let fileContent = fs.readFileSync(fileToBuild, 'utf8');
		fileContent = replaceEnvironmentVariables(fileContent);
		minifiedContent = minifyFile(fileContent);
		saveProcessedFile(fileContent, fileToBuild);
		saveProcessedFile(minifiedContent, fileToBuild.replace('.js', '.min.js'));
	} catch (err) {
		console.error(`Error processing file ${fileToBuild}: ${err}`);
		process.exit(1);
	}
}

// Execute the build process
buildFile();
