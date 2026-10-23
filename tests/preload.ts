// Until BND-11 adds keep-alive, test servers close the connection after
// every response without sending `Connection: close`. Bun's fetch would pool
// the socket and sometimes reuse it after the server closed it (ECONNRESET).
// Turn connection reuse off for every test fetch. BND-11 removes this file
// once servers announce the close or keep the connection alive.
const original = globalThis.fetch;

const fetchWithoutReuse: typeof fetch = Object.assign(
  (input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) =>
    original(input, { ...init, keepalive: false }),
  original,
);

globalThis.fetch = fetchWithoutReuse;
