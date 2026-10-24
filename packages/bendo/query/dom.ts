// A DOM for React Testing Library. Import it before React: react-dom checks for
// `document` when it loads. Happy DOM replaces fetch, AbortSignal and the timers
// with its own; the client must keep Bun's, since Bun's fetch refuses a Happy DOM
// signal, so those globals are put back.
import { GlobalRegistrator } from "@happy-dom/global-registrator";

const native = [
  "fetch",
  "Request",
  "Response",
  "Headers",
  "FormData",
  "Blob",
  "File",
  "URL",
  "URLSearchParams",
  "AbortController",
  "AbortSignal",
  "ReadableStream",
  "TextEncoder",
  "TextDecoder",
  "setTimeout",
  "clearTimeout",
  "setInterval",
  "clearInterval",
  "queueMicrotask",
  "structuredClone",
  "performance",
] as const;

const saved = native.map(
  (name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)] as const,
);
GlobalRegistrator.register();
for (const [name, descriptor] of saved)
  if (descriptor !== undefined) Object.defineProperty(globalThis, name, descriptor);

/** Restores the globals Happy DOM replaced, so later files in this process see Bun's. */
export async function unregisterDom(): Promise<void> {
  await GlobalRegistrator.unregister();
}
