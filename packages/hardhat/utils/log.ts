function log(message: any, functionName: string) {
  const greenFill = "\x1b[42m";
  const reset = "\x1b[0m";
  console.log(`${greenFill}[${functionName}]${reset}`, message);
}

export default log;
