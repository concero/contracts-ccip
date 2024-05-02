// tries to load file asynchroniously
// WARNING: path must be relative to THIS FILE, not the file that uses the function.
async function load(path: string) {
  try {
    const file = await import(path);
    return file;
  } catch (error) {
    console.error("Failed to load file:", error);
  }
}

export default load;
