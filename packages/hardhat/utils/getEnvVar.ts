import { type env } from "../types/env";
import process from "process";
export function getEnvVar(key: keyof env): string {
  const value = process.env[key];
  if (value === undefined) throw new Error(`Missing required environment variable ${key}`);
  if (value === "") throw new Error(`${key} must not be empty`);
  return value;
}
