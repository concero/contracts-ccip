export function getEnvVar(key: string): string | undefined {
  const value = process.env[key];
  if (value === undefined) throw new Error(`Missing required environment variable ${key}`);
  if (value === "") throw new Error(`${key} must not be empty`);
  return value;
}
