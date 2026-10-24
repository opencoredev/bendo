import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The form imports ../dist/shared/signup.mjs, which `bendo build --shared`
// writes from ../shared/signup.bend. /api goes to the compiled Bend server.
export default defineConfig({
  plugins: [react()],
  server: {
    fs: { allow: [".."] },
    proxy: { "/api": process.env.BENDO_API ?? "http://127.0.0.1:8787" },
  },
});
