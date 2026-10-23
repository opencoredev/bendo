import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// build/ rather than dist/: the repository ignores dist/ directories.
export default defineConfig({
  plugins: [react()],
  build: { outDir: "build", emptyOutDir: true },
});
