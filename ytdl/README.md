# Omarchy Shell Plugin for yt-dlp

A yt-dlp video downloader for the Omarchy bar. The bar widget shows the active download count and opens a panel with live progress, speed and ETA for up to three parallel downloads, a quality selector, and a persistent history.

## Features

- Bar widget with active download count
- Parallel downloads with live progress, speed and ETA
- Automatic clipboard detection of YouTube links
- Quality selector cycled from the panel (persisted across restarts)
- Download history with play, retry and remove actions
- Deleted files are auto-pruned from the history
- Auto-installs yt-dlp from the panel when missing

## Requirements

- Omarchy quattro
- yt-dlp (auto-installed from the panel if missing)
- wl-clipboard (provides `wl-paste`; preinstalled on Omarchy) for clipboard detection
- jq (preinstalled on Omarchy) for pruning deleted files from the history
- sqlite3 (preinstalled on Omarchy) only for cookie export from Firefox-based browsers (zen, glide); skipped entirely otherwise

## Install

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-ytdl.git --enable
```

## Usage

Click the bar widget to open the download panel. Copy a YouTube link to the clipboard and it is detected automatically; press the download button (or Enter) to start. Click the quality label to cycle `best` / `1080p` / `720p` / `480p`.

You can also bind it to a key (`~/.config/hypr/bindings.lua`):

```lua
o.bind("CTRL", "D", "exec, omarchy-shell shell summon bibek.ytdl")
```

## Configuration

Options go under the plugin entry in `~/.config/omarchy/shell.json`:

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
| `extraArgs` | (empty) | Any yt-dlp flags, e.g. `--cookies-from-browser chromium` |

### Fixing YouTube bot detection

If yt-dlp fails with "Sign in to confirm you're not a bot", log into YouTube in your browser and set `cookiesBrowser` to that browser. The plugin only exports cookies on demand: every download first tries without cookies and only retries with `--cookies-from-browser` if the bot check appears, so no cookies are read for the common case.

For fine-grained control, set `extraArgs` directly (e.g. `--cookies-from-browser chromium`).

## Troubleshooting

If a download fails, test yt-dlp directly in the terminal first:

```bash
yt-dlp -f "b[height<=1080]/b" "https://www.youtube.com/watch?v=..."
```

- If the yt-dlp CLI fails, do not open an issue here. Report it upstream at https://github.com/yt-dlp/yt-dlp/issues or ask on the yt-dlp Discord (https://discord.gg/H5MNcFW63r).
- If the CLI works with different arguments, set them in the `extraArgs` setting above.
- Only if the CLI works but the widget does not, open an issue in this repository.

## Uninstall

```bash
omarchy plugin remove bibek.ytdl
```

## Credits

Download logic based on the yt-dlp docs on exporting YouTube cookies (https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies) and on the Quickshell `Process` / `IpcHandler` patterns from the omarchy-aria2 reference repo.

This plugin is licensed under the [MIT License](../LICENSE).

## Others

Here are my other Omarchy plugins:

- [Focusd](https://github.com/BibekBhusal0/omarchy-focusd) - pomodoro timer with streak, history and daily goal
- [Obsidian Search](https://github.com/BibekBhusal0/omarchy-obsidian-search) - fuzzy-search your Obsidian vault
- [Readest](https://github.com/BibekBhusal0/omarchy-readest) - fuzzy-search your Readest library

Please give a star if you find them useful!