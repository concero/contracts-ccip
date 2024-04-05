// This worked in Production Functions
// Request: https://functions.chain.link/mumbai/1437/0xe36aebfa2b46aa9fc6f82cab0f1e8312076ca7ffe8a8f8fe5beaec033607320e
// TX Hash: 0x66175b8d32b52bc3c94679ada0b9eea7dc33d9677d526e797594582fe950ae2c

async function performRequest(args) {
  const url = `https://swapi.dev/api/people/1`;
  const req = fetch(url, {
    headers: {
      "Content-Type": "application/json",
    },
  });
  const res = await req;
  const data = await res.json();
  return Functions.encodeString(data.name);
}

performRequest();
