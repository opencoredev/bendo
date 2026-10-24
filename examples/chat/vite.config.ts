import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The Bend server runs on its own port (CHAT_API, default 8787). Vite proxies
// the socket and the room counts to it, so the app talks to one origin.
const api = process.env.CHAT_API ?? "http://127.0.0.1:8787";
const proxy = {
  "/api": { target: api },
  "/ws": { target: api, ws: true },
};

export default defineConfig({
  plugins: [react()],
  server: { host: "127.0.0.1", port: 5173, strictPort: true, proxy },
  preview: { host: "127.0.0.1", port: 5173, strictPort: true, proxy },
});
