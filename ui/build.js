const esbuild = require("esbuild");
const sveltePlugin = require("esbuild-svelte");

esbuild.build({
  entryPoints: ['./siren.js'],
  outdir: '../docroot/s/',
  format: "esm",
  minify: false,
  bundle: true,
  splitting: true,
  sourcemap: true,
  plugins: [sveltePlugin(),]
}).catch((err) => {
  console.error(err)
  process.exit(1)
})
