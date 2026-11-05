const PAYLOAD_URL = 'https://speed.cloudflare.com/__down?bytes=';

export async function downloadPayload(bytes: number) {
  const response = await fetch(`${PAYLOAD_URL}${bytes}`);

  if (!response.ok) {
    throw new Error(`Download failed with status ${response.status}`);
  }

  const payload = await response.arrayBuffer();

  return payload.byteLength;
}
