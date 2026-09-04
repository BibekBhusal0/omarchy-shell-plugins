# AGENTS.md

Use `omarchy` skill before making any changes.

## Repo layout

Monorepo of standalone Omarchy shell plugins. Each folder is its own plugin with a `manifest.json`, and publishes to its own git repo (see `manifest.json` `homepage`):

| Folder             | Kind                 | Description                                        |
| ------------------ | -------------------- | -------------------------------------------------- |
| `focusd/`          | bar-widget + service | Focus timer with progress bar and panel            |
| `lock/`            | service              | Lock screen with date/time, media, power controls  |
| `media/`           | bar-widget + service | Media player controls and now-playing info         |
| `obsidian-search/` | menu (overlay)       | Fuzzy search across Obsidian vaults                |
| `readest/`         | menu (overlay)       | Fuzzy search across Readest library                |
| `ytdl/`            | bar-widget + service | YouTube video downloader with clipboard monitoring |

`banners/` holds the preview-image studio (not a plugin; `publish.sh` skips it because there is no `manifest.json`). `bun screenshot.ts` inside it renders each plugin's `preview.png` (1600x800) from `banners.js` data.

`scripts/publish.sh` + `.github/workflows/publish.yml` push each plugin folder to its standalone repo and cut a `v<version>` release.

## How the dev loop works (critical)

QML runs inside the long-lived `omarchy-shell` (Quickshell) process; there is **no build step** for the plugin code itself. The shell only hot-reloads files under `~/.config/omarchy/plugins/<id>/` — **not** files in this repo.

- `scripts/watch-sync.sh` watches this repo with `inotifywait` and copies changed `.qml/.js/.json/.sh` files into `~/.config/omarchy/plugins/<id>/`. Run it as a systemd user unit: `systemd-run --user --unit=plugin-watch --collect --working-directory=<repo> <repo>/scripts/watch-sync.sh` (currently active). It's also launched from `.tmuxinator.yml`.
- **Never symlink** `~/.config/omarchy/plugins/<id>` to this repo: inotify does not follow symlinks, so hot-reload silently breaks (verified empirically). Keep real dirs.

## Plugin install and test workflow

To install a plugin from this repo into the live shell:

1. **Copy plugin files** to the user plugins directory:

   ```bash
   mkdir -p ~/.config/omarchy/plugins/<plugin-folder-name>
   cp -a <repo>/<plugin-folder>/. ~/.config/omarchy/plugins/<plugin-folder-name>/
   ```

   **Important**: Use the folder name (e.g., `focusd`), not the plugin ID from manifest.json (e.g., `bibek.focusd`).

2. **Register the plugin** in `~/.config/omarchy/shell.json`:
   - Add `{"id": "<plugin-id>"}` to the `plugins` array (for services/overlays).
   - For bar widgets, also add `{"id": "<plugin-id>"}` to `bar.layout.right` (or `left`/`center`).

3. **Restart the shell** to load changes:

   ```bash
   omarchy-restart-shell
   ```

4. **Test the plugin** by summoning it:

   ```bash
   omarchy-shell shell summon <plugin-id>
   ```

   Check for errors in the output. If there are QML errors, they will show in the shell output.

5. **Iterate**: Edit files in the repo, re-copy to `~/.config/omarchy/plugins/<plugin-folder-name>/`, restart shell, test again. The shell hot-reloads on file save when the plugin dir is a real directory (not a symlink).

**Tip**: Use `omarchy-shell shell call <plugin-id> state` to inspect live plugin state for debugging.

## Comment conventions

- **No slop comments.** Never add decorative section dividers (`# ------`), "talking to the reader" comments, or obvious comments that restate the code.
- **High-value comments only.** Use comments to break down complex logic: non-obvious constants (like AT-SPI role codes), protocol message formats, timing-sensitive code, or workarounds.
- **No mdashes in README files.**.
- **No comments in Code** unless explaining a non-obvious behavior or workaround.
- **Icon comments required for new/modified components only.** When adding a new QML component or modifying an existing one that uses Nerd Font icon glyphs, add `// FIX: icon below` on the line above the `iconText` property. Do not add this comment to existing, unmodified components that already have icons.

## Formatting

- **Prettier** handles JS, JSON, and MD files. Config: `.prettierrc` (2-space indent, double quotes).
- **qmlformat** (Qt 6) handles QML files. Config: `.qmlformat.ini` (2-space indent).
  - Use `/usr/lib/qt6/bin/qmlformat`, not the Qt 5 version at `/usr/bin/qmlformat`.
  - Command: `/usr/lib/qt6/bin/qmlformat -i $(find . -name '*.qml' ! -path './.git/*')`
- CI auto-formats on push to `main` via `.github/workflows/format.yml`: runs prettier and qmlformat, then commits any changes back using `stefanzweifel/git-auto-commit-action`.

## Plugin conventions

- `manifest.json` is the schema source of truth: `kinds`, `entryPoints`, and `barWidget.schema`/`defaults` define what the shell reads. New configurable options must be added there.
- Settings helpers are inherited from the shell's `Panel`/`BarWidget` base (see `/usr/share/omarchy/shell/Ui/Panel.qml:39`): `setting(name, fallback)` reads `settings[name]`. Dotted keys like `icons.work` work.
- **Keyboard navigation required:** Interactive components (panels, lock screen overlays, controls) must support full keyboard navigation (Tab/Shift+Tab, Arrow keys, Enter/Space activation, Esc).

## Plugin specifics

- **focusd**: `Service.qml` drives the external `focusd` CLI (must be on `$PATH`) via `Quickshell.execDetached(["focusd", "toggle"])`. Timer state flows to the UI from the daemon. Bar icons are Nerd Font codepoints. Default config (`progressBarStyle`, `icons`) is in `manifest.json` `barWidget.defaults`; README documents it.
- **lock**: clone of built-in `omarchy.lock` (manifest id `bibek.lock`, `omarchy.clonedFrom` set). Adds big customizable date/time text, power control buttons (shutdown, restart, sleep), MPRIS media player controls, forgot password prompt with top warning display, and full keyboard navigation across all controls. Built-in `omarchy.lock` is disabled via `disabledPlugins`.
- **media**: clone of the built-in `omarchy.media` (manifest id `bibek.media`, `omarchy.clonedFrom` set). The built-in is disabled via `disabledPlugins` so its IPC `media` target doesn't collide. `BarWidget.qml` must look up the service by the clone id (`firstPartyServiceFor("bibek.media")`), not the built-in id.
- **obsidian-search / readest**: rely on `fd` + `jq` and `FuzzySearch.js`. Obsidian vault path defaults to the first vault in `~/.config/obsidian/obsidian.json`; Readest defaults to the Readest data dir under `~/.var/app/com.bilingify.readest/`. Both are overridable via `vaultPath` / `libraryPath` in the plugin entry of `~/.config/omarchy/shell.json`.
- **ytdl**: yt-dlp video downloader. Service manages downloads via Process objects, monitors clipboard for YouTube URLs when a browser is focused. Download format args must NOT use `bestvideo+bestaudio` style selectors (causes HTTP 403 on YouTube) -- use `b[height<=X]/b` fallback chains or omit format for "best". Browser detection list must include `zen`, `helium`, `glide`. YouTube bot detection is bypassed via `cookiesBrowser`/`extraArgs` settings; Firefox-based browsers (zen, glide) lock their cookie DB while running so the shell `export_cookies()` in the `ytdl` script merges the sqlite+wal (via `PRAGMA wal_checkpoint`) and dedupes with a window function, and the script auto-selects the profile that has a logged-in SID. Helium is Chromium-based (cookies passed via profile dir).

## Requirements (documented in each plugin README)

- All plugins require Omarchy quattro.
- `fd` + `jq` are preinstalled on Omarchy; search plugins list them as preinstalled requirements, not as install steps.
- focusd requires the `focusd` binary on `$PATH`.

## Banners

`banners/` renders each marketplace plugin's `preview.png` (1600x800). Run `bun screenshot.ts` from inside it.

- Banner copy lives in each plugin's `manifest.json` under `preview` (tagline, icon, bullets, shot). Name/id/version are reused for the heading and footer.
- `screenshot.ts` discovers every plugin folder with a `preview` key and passes each banner as JSON in `index.html?banner=...`, saving `../<plugin>/preview.png`.
- `banners.js` holds one static `addBanner` renderer plus a single sample banner for style preview. Title shrinks automatically past 16 chars.
- `publish.sh` strips `.preview` from manifests before pushing to standalone repos; marketplace and shell never see it.
- `background.jpg` is the shared backdrop. `app/` has brand marks, `screenshot/` has raw plugin UI captures, `icons/` has bullet icons (white baked in; edit the SVG to recolor).
- Quirks this backend forces: `?banner=` full reloads (scrollTo/evaluate broken, same-document `#` jumps hang navigate), zero body padding in single mode, 887px viewport height to land exactly 800px (backend crops 87px).

## Publishing

- Bump `version` in a plugin's `manifest.json`, `publish.sh` skips a plugin if the remote manifest already matches the local version. Do not bump version unless user ask to.
- Publish flow runs on push to `main` or `workflow_dispatch`; needs `PAT_TOKEN` (repo scope) set on the repo. Dry-run locally: `GITHUB_TOKEN=... bash scripts/publish.sh`.

## Environment notes

- Background daemons/commands can hang interactive tool shells, prefer `systemd-run --user` for long-lived watchers.
