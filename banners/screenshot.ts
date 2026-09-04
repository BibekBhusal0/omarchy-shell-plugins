import { WebView } from "bun";

const source = await Bun.file(`${import.meta.dir}/banners.js`).text();
const files = [...source.matchAll(/file:\s*"([^"]+)"/g)].map((m) => m[1]);

const view = new WebView({ width: 1600, height: 887, backend: "chrome" });

for (let i = 0; i < files.length; i++) {
  await view.navigate(`file://${import.meta.dir}/index.html?banner=${i}`);
  const blob = await view.screenshot({ format: "png" });
  await Bun.write(`${import.meta.dir}/${files[i]}`, blob);
  console.log("saved", files[i]);
}

await view.close();
