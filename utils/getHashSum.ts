function getHashSum(sourceCode: string) {
  const hash = require("crypto").createHash("sha256");
  hash.update(sourceCode, "utf8");
  return `0x${hash.digest("hex")}`;
}

export default getHashSum;
