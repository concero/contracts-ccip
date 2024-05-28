"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ora_1 = __importDefault(require("ora"));
function spin(config = {}) {
    const spinner = (0, ora_1.default)({ spinner: "dots2", ...config });
    spinner.start();
    return spinner;
}
exports.default = spin;
