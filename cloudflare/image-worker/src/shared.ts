/// Helpers that belong to no single provider.
///
/// These were in `index.ts` when Gemini was the only image provider, so
/// "shared" and "Gemini" were the same thing. They are separated here so a
/// second provider can reuse them without importing the request handler, and so
/// the provider adapters stay free of anything but their own API.

/// An error whose message is safe to return to the caller.
///
/// Anything else is reported as a generic failure, so provider internals and
/// key material can never reach the client through an error path.
export class PublicWorkerError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

/// Chunked on purpose: spreading a whole sheet into `String.fromCharCode` blows
/// the argument limit on a megabyte-scale image.
export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 32_768) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 32_768));
  }
  return btoa(binary);
}

export function base64ToBytes(data: string): Uint8Array {
  const binary = atob(data);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

/// Reads the real format and dimensions out of the returned bytes.
///
/// The declared MIME type is what the provider *says* it sent. This is what it
/// actually sent, which is the only thing worth validating a contract against.
export function imageDetails(
  bytes: Uint8Array,
): { mimeType: string; width: number; height: number } | null {
  if (
    bytes.length > 24 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    return {
      mimeType: "image/png",
      width: view.getUint32(16),
      height: view.getUint32(20),
    };
  }
  if (bytes.length > 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset + 8 < bytes.length) {
      if (bytes[offset] !== 0xff) {
        offset++;
        continue;
      }
      const marker = bytes[offset + 1];
      const length = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (length < 2) break;
      if (
        marker >= 0xc0 &&
        marker <= 0xc3
      ) {
        return {
          mimeType: "image/jpeg",
          height: (bytes[offset + 5] << 8) | bytes[offset + 6],
          width: (bytes[offset + 7] << 8) | bytes[offset + 8],
        };
      }
      offset += length + 2;
    }
  }
  return null;
}
