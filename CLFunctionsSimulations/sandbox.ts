// secrets, args & bytesArgs are made available to the user's script
// deno-lint-ignore no-unused-vars

export const Functions = {
  makeHttpRequest: async ({ url, method = 'get', params, headers, data, timeout = 3000, responseType = 'json' }) => {
    try {
      if (params) {
        url += '?' + new URLSearchParams(params).toString();
      }

      // Setup controller for timeout
      const controller = new AbortController();
      const id = setTimeout(() => controller.abort(), timeout);
      const result = await fetch(url, {
        method,
        headers,
        body: data ? JSON.stringify(data) : undefined,
        signal: controller.signal,
      });
      clearTimeout(id);

      if (result.status >= 400) {
        const errorResponse = {
          error: true,
          message: result.statusText,
          code: result.status.toString(),
          response: result,
        };
        return errorResponse;
      }

      const successResponse = {
        error: false,
        status: result.status,
        statusText: result.statusText,
        headers: result.headers ? Object.fromEntries(result.headers.entries()) : undefined,
      };

      console.log('responseType', responseType);
      switch (responseType) {
        case 'json':
          successResponse.data = await result.json();
          break;
        case 'arraybuffer':
          successResponse.data = await result.arrayBuffer();
          break;
        case 'document':
          successResponse.data = await result.text();
          break;
        case 'text':
          successResponse.data = await result.text();
          break;
        case 'stream':
          successResponse.data = result.body;
          break;
        default:
          throw new Error('invalid response type');
      }
      console.log('successResponse', successResponse);
      return successResponse;
    } catch (e) {
      return {
        error: true,
        message: e?.toString?.(),
      };
    }
  },

  encodeUint256: (num: bigint | number): Uint8Array => {
    if (typeof num !== 'number' && typeof num !== 'bigint') {
      throw new Error('input into Functions.encodeUint256 is not a number or bigint');
    }
    if (typeof num === 'number') {
      if (!Number.isInteger(num)) {
        throw new Error('input into Functions.encodeUint256 is not an integer');
      }
    }
    num = BigInt(num);
    if (num < 0) {
      throw new Error('input into Functions.encodeUint256 is negative');
    }
    if (num > 2n ** 256n - 1n) {
      throw new Error('input into Functions.encodeUint256 is too large');
    }

    let hexStr = num.toString(16); // Convert to hexadecimal
    hexStr = hexStr.padStart(64, '0'); // Pad with leading zeros
    if (hexStr.length > 64) {
      throw new Error('input is too large');
    }
    const arr = new Uint8Array(32);
    for (let i = 0; i < arr.length; i++) {
      arr[i] = parseInt(hexStr.slice(i * 2, i * 2 + 2), 16);
    }
    return arr;
  },

  encodeInt256: (num: bigint | number): Uint8Array => {
    if (typeof num !== 'number' && typeof num !== 'bigint') {
      throw new Error('input into Functions.encodeInt256 is not a number or bigint');
    }
    if (typeof num === 'number') {
      if (!Number.isInteger(num)) {
        throw new Error('input into Functions.encodeUint256 is not an integer');
      }
    }
    num = BigInt(num);
    if (num < -(2n ** 255n)) {
      throw new Error('input into Functions.encodeInt256 is too small');
    }
    if (num > 2n ** 255n - 1n) {
      throw new Error('input into Functions.encodeInt256 is too large');
    }

    let hexStr;
    if (num >= BigInt(0)) {
      hexStr = num.toString(16); // Convert to hexadecimal
    } else {
      // Calculate two's complement for negative numbers
      const absVal = -num;
      let binStr = absVal.toString(2); // Convert to binary
      binStr = binStr.padStart(256, '0'); // Pad to 256 bits
      // Invert bits
      let invertedBinStr = '';
      for (const bit of binStr) {
        invertedBinStr += bit === '0' ? '1' : '0';
      }
      // Add one
      let invertedBigInt = BigInt('0b' + invertedBinStr);
      invertedBigInt += 1n;
      hexStr = invertedBigInt.toString(16); // Convert to hexadecimal
    }
    hexStr = hexStr.padStart(64, '0'); // Pad with leading zeros
    if (hexStr.length > 64) {
      throw new Error('input is too large');
    }
    const arr = new Uint8Array(32);
    for (let i = 0; i < arr.length; i++) {
      arr[i] = parseInt(hexStr.slice(i * 2, i * 2 + 2), 16);
    }
    return arr;
  },

  encodeString: (str: string): Uint8Array => {
    const encoder = new TextEncoder();
    return encoder.encode(str);
  },
};

try {
  const userScript = (async () => {
    //INJECT_USER_CODE_HERE
  }) as () => Promise<unknown>;
  const result = await userScript();

  if (!(result instanceof ArrayBuffer) && !(result instanceof Uint8Array)) {
    throw Error('returned value not an ArrayBuffer or Uint8Array');
  }

  const arrayBufferToHex = (input: ArrayBuffer | Uint8Array): string => {
    let hex = '';
    const uInt8Array = new Uint8Array(input);

    uInt8Array.forEach(byte => {
      hex += byte.toString(16).padStart(2, '0');
    });

    return '0x' + hex;
  };

  console.log(
    '\n' +
      JSON.stringify({
        success: arrayBufferToHex(result),
      }),
  );
} catch (e: unknown) {
  let error: Error;
  if (e instanceof Error) {
    error = e;
  } else if (typeof e === 'string') {
    error = new Error(e);
  } else {
    error = new Error(`invalid value thrown of type ${typeof e}`);
  }

  console.log(
    '\n' +
      JSON.stringify({
        error: {
          name: error?.name ?? 'Error',
          message: error?.message ?? 'invalid value returned',
          details: error?.stack ?? undefined,
        },
      }),
  );
}
