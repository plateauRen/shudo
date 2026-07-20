const esbuild = require("esbuild");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const outDir = path.join(
  root,
  "../../../ios/Modules/WuKongBase/WuKongBase/Assets/RichEditor"
);

async function main() {
  fs.mkdirSync(outDir, { recursive: true });
  await esbuild.build({
    entryPoints: [path.join(root, "webview/main.ts")],
    bundle: true,
    outfile: path.join(outDir, "bridge.js"),
    format: "iife",
    platform: "browser",
    target: ["es2018"],
    minify: true,
    sourcemap: false,
    define: {
      "process.env.NODE_ENV": '"production"',
    },
  });
  fs.copyFileSync(
    path.join(root, "webview/index.html"),
    path.join(outDir, "index.html")
  );
  console.log("Rich editor webview built ->", outDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
