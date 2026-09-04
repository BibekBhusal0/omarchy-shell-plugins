import { WebView } from "bun";

const dir = import.meta.dir;
const ROOT = `${dir}/..`;

// Backend crops 87px off the captured height, so 887 lands exactly 800.
const view = new WebView({ width: 1600, height: 887, backend: "chrome" });

for await (const path of new Bun.Glob("*/manifest.json").scan(ROOT)) {
  const manifest = await Bun.file(`${ROOT}/${path}`).json();
  if (!manifest.preview) continue;
  const payload = encodeURIComponent(
    JSON.stringify({
      name: manifest.name,
      icon: manifest.preview.icon,
      tagline: manifest.preview.tagline,
      bullets: manifest.preview.bullets,
      shot: manifest.preview.shot,
      id: manifest.id,
      version: manifest.version,
    }),
  );
  await view.navigate(`file://${dir}/index.html?banner=${payload}`);
  const blob = await view.screenshot({ format: "png" });
  const out = `${path.split("/")[0]}/preview.png`;
  await Bun.write(`${ROOT}/${out}`, blob);
  console.log("saved", out);
}

await view.close();
