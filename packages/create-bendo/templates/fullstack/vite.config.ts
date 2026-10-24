import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import bendo from "vite-plugin-bendo";

// `bun run dev` starts the Bendo API on API_PORT and Vite beside it.
const api = `http://127.0.0.1:${process.env.API_PORT ?? "8787"}`;

export default defineConfig({
  plugins: [react(), bendo()],
  build: { outDir: "dist/web", emptyOutDir: true },
  server: { host: "127.0.0.1", proxy: { "/api": api } },
  preview: { host: "127.0.0.1", proxy: { "/api": api } },
});
