import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import bendo from "vite-plugin-bendo";

// vite-plugin-bendo compiles shared/todo.bend for the browser, so the forms
// check input with the decoder the API's routes declare. The API runs on its
// own origin (BENDO_API, default port 8787) and answers CORS for this one.
export default defineConfig({
  plugins: [react(), bendo()],
  server: { host: "127.0.0.1", port: 5173, strictPort: true },
  preview: { host: "127.0.0.1", port: 5173, strictPort: true },
});
