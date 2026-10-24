import { defineConfig } from "vite";
import bendo from "../../src/index.ts";

export default defineConfig({
  plugins: [bendo()],
});
