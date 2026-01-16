import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
  },
  build: {
    // Canva "JavaScript bundle" upload expects a single .js file.
    // We force Vite/Rollup to emit one JS output and inline assets.
    cssCodeSplit: false,
    assetsInlineLimit: 10_000_000,
    rollupOptions: {
      output: {
        entryFileNames: "app.js",
        chunkFileNames: "app.js",
        assetFileNames: "app.[ext]",
        inlineDynamicImports: true,
      },
    },
  },
});

