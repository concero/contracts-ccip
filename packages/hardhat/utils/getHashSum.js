"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function getHashSum(sourceCode) {
    const hash = require("crypto").createHash("sha256");
    hash.update(sourceCode, "utf8");
    return `0x${hash.digest("hex")}`;
}
exports.default = getHashSum;
