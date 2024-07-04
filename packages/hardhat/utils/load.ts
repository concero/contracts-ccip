// tries to load file asynchroniously
// WARNING: path must be relative to THIS FILE, not the file that uses the function.
async function load(path: string) {
  return await import(path);
}

export default load;
