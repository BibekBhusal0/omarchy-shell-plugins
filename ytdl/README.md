# bibek.ytdl

yt-dlp video downloader for the Omarchy bar.

## Features

- Download videos from YouTube and other sites via yt-dlp
- Parallel downloads with progress tracking
- Automatic clipboard URL detection when a browser is focused
- Configurable download location and default quality
- Download history with retry and remove actions
- Play downloaded videos directly from the panel
- Install yt-dlp from the panel if not already installed

## Requirements

All preinstalled on Omarchy:

- yt-dlp (auto-installed from the panel if missing, via `omarchy pkg add yt-dlp`)
- wl-paste (for clipboard URL detection)
- jq (used to prune deleted files from download history)
- `sqlite3` CLI - only needed when `cookiesBrowser` is set to a Firefox-based
  browser (zen, glide); cookie handling is skipped entirely otherwise

## Settings

Configure in `~/.config/omarchy/shell.json` under the plugin entry:

```json
{
  "id": "bibek.ytdl",
  "downloadLocation": "~/Downloads/yt-dlp",
  "defaultQuality": "best",
  "cookiesBrowser": "none",
  "extraArgs": ""
}
```

| Setting | Default | Options |
|---------|---------|---------|
| `downloadLocation` | `~/Downloads/yt-dlp` | Any valid directory path |
| `defaultQuality` | `best` | `best`, `1080p`, `720p`, `480p` |
| `cookiesBrowser` | `none` | `none`, `firefox`, `chromium`, `chrome`, `zen`, `helium`, `glide` |
| `extraArgs` | `` | Any yt-dlp flags, e.g. `--cookies-from-browser chromium` |

### Fixing YouTube bot detection

If yt-dlp fails with "Sign in to confirm you're not a bot", log into YouTube in
your browser, then set `cookiesBrowser` to that browser. The plugin only
exports cookies on demand: every download first tries without cookies, and only
retries with `--cookies-from-browser` if the bot check appears. So no cookies
are read or copied for the common case.

For fine-grained control, set `extraArgs` directly (e.g.
`--cookies-from-browser chromium`).

## Bar Widget

- Left click opens the download panel
- Icon shows active download count when downloads are in progress

## Inspiration

- yt-dlp's own FAQ and extractor docs on exporting YouTube cookies
  (https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies)
- omaqbt, omarr and omarchy-aria2 reference repos for the Quickshell Process /
  IpcHandler patterns used here
