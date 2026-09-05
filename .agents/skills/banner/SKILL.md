---
name: banner
description: >
  REQUIRED for creating or updating marketplace preview banners in the
  omarchy-shell-plugins monorepo. Use when editing banners/, preview.png,
  manifest.json preview keys, or rendering screenshots with bun.
  Triggers: banner, preview image, preview.png, banners.js, screenshot.ts,
  manifest preview key, marketplace preview.
---

# Banner Skill

Render each plugin's 1600x800 `preview.png` from `banners/`.

## Change banner copy

Edit the plugin's `manifest.json` under the `preview` key
(`tagline`, `icon`, `bullets` as `[icon, text]` pairs, `shot`).
`name`/`id`/`version` are reused for the heading and footer.
Asset paths resolve relative to `banners/`.

## Render

Run from `banners/`:

```bash
bun screenshot.ts
```

This discovers every plugin folder with a `preview` key, passes each
banner as JSON in `index.html?banner=...`, and saves
`../<plugin>/preview.png`. No manual render is needed before a version
bump: CI regenerates previews in the format job, so both the monorepo
and the published child repos always ship fresh images.

## Add a new banner

1. Capture the plugin UI (e.g. `grim ~/Pictures/shot.png`) into
   `banners/screenshot/<name>.png`, cropped tight, no rounding.
2. Put the brand mark in `banners/app/`.
3. Pick bullet icons from `banners/icons/`. New HugeIcons come from the
   Iconify API, then replace `currentColor` with `#fff`:
   `curl "https://api.iconify.design/hugeicons:<name>.svg" -o banners/icons/hugeicons--<name>.svg`
4. Add the `preview` key to the plugin's `manifest.json` and render.

## Rules

- SVG markup lives only in `.svg` files. Bullets render as plain `<img>`.
- Icon color is baked into the SVG file. Page CSS cannot recolor `<img>`.
- `banners.js` holds one static renderer plus a single sample banner.
  Title shrinks automatically past 16 chars.
- Backend quirks: `?banner=` full reloads only (scrollTo/evaluate are
  broken, same-document `#` jumps hang navigate), zero body padding in
  single mode, 887px viewport height to land exactly 800px.
