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

## Update bullets, icons, or tagline

Edit the `preview` key in the plugin's `manifest.json`:

- `bullets` are `[icon, text]` pairs. Reorder, reword, add, or drop
  rows freely; paths resolve relative to `banners/`.
- Reuse icons from `banners/icons/`. For a new one, fetch it first
  (see below), then reference its path.
- `tagline` is one line under the plugin name. Keep it under ~45 chars.
- `shot` points at `banners/screenshot/<name>.png`. Re-capture with
  `grim ~/Pictures/shot.png` if the UI changed, cropped tight.

Then render with `bun screenshot.ts`. CI regenerates on push anyway,
but render locally to preview the result.

## Fetch a new icon

HugeIcons via the Iconify API, whitened to match the set:

```bash
curl "https://api.iconify.design/hugeicons:<name>.svg" -o banners/icons/hugeicons--<name>.svg
```

Then replace `currentColor` with `#fff` in the file. Verify the
download is a real icon (contains `currentColor`), not an API error.

## Add a new banner

1. Capture the plugin UI into `banners/screenshot/<name>.png`.
2. Put the brand mark in `banners/app/`.
3. Add the `preview` key to the plugin's `manifest.json` and render.

## Style guidelines

- Max 4 bullets, 3 is ideal. Each bullet earns its place: drop
  anything that restates the tagline or lists trivia.
- Bullets are short phrases, not sentences. No trailing periods.
  Aim under ~45 characters so nothing wraps awkwardly.
- Tagline is one line, user-facing benefit, not a feature list.
- Write for the user ("Find any note"), not the implementation
  ("Fuzzy search with relevance ranking").
- Screenshots: cropped tight on the UI, no window chrome, no rounding
  (the frame adds that). Around 350-650px wide; height is flexible.
- Brand marks: SVG preferred, PNG with transparency accepted.

## Rules

- SVG markup lives only in `.svg` files. Bullets render as plain `<img>`.
- Icon color is baked into the SVG file. Page CSS cannot recolor `<img>`.
- `banners.js` holds one static renderer plus a single sample banner.
  Title shrinks automatically past 16 chars.
- Backend quirks: `?banner=` full reloads only (scrollTo/evaluate are
  broken, same-document `#` jumps hang navigate), zero body padding in
  single mode, 887px viewport height to land exactly 800px.
