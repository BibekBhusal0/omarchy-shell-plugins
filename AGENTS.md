# AGENTS.md

Use `omarchy` skill before making any changes.

## Repo layout

Monorepo of standalone Omarchy shell plugins. Each folder is its own plugin with a `manifest.json`, and publishes to its own git repo (see `manifest.json` `homepage`):

| Folder             | Kind                 | Key files                                           |
| ------------------ | -------------------- | --------------------------------------------------- |
| `focusd/`          | bar-widget + service | `BarWidget.qml`, `Panel.qml`, `Service.qml`         |
| `obsidian-search/` | menu (overlay)       | `ObsidianSearch.qml`, `search.sh`, `FuzzySearch.js` |
| `readest/`         | menu (overlay)       | `Readest.qml`, `search.sh`, `FuzzySearch.js`        |

`scripts/publish.sh` + `.github/workflows/publish.yml` push each plugin folder to its standalone repo and cut a `v<version>` release.

## How the dev loop works (critical)

QML runs inside the long-lived `omarchy-shell` (Quickshell) process; there is **no build step** for the plugin code itself. The shell only hot-reloads files under `~/.config/omarchy/plugins/<id>/` — **not** files in this repo.

- `scripts/watch-sync.sh` watches this repo with `inotifywait` and copies changed `.qml/.js/.json/.sh` files into `~/.config/omarchy/plugins/<id>/`. Run it as a systemd user unit: `systemd-run --user --unit=plugin-watch --collect --working-directory=<repo> <repo>/scripts/watch-sync.sh` (currently active). It's also launched from `.tmuxinator.yml`.
- **Never symlink** `~/.config/omarchy/plugins/<id>` to this repo: inotify does not follow symlinks, so hot-reload silently breaks (verified empirically). Keep real dirs.

## Plugin conventions

- `manifest.json` is the schema source of truth: `kinds`, `entryPoints`, and `barWidget.schema`/`defaults` define what the shell reads. New configurable options must be added there.
- Settings helpers are inherited from the shell's `Panel`/`BarWidget` base (see `/usr/share/omarchy/shell/Ui/Panel.qml:39`): `setting(name, fallback)` reads `settings[name]`. Dotted keys like `icons.work` work.

## Plugin specifics

- **focusd**: `Service.qml` drives the external `focusd` CLI (must be on `$PATH`) via `Quickshell.execDetached(["focusd", "toggle"])`. Timer state flows to the UI from the daemon. Bar icons are Nerd Font codepoints. Default config (`progressBarStyle`, `icons`) is in `manifest.json` `barWidget.defaults`; README documents it.
- **obsidian-search / readest**: rely on `fd` + `jq` and `FuzzySearch.js`. Obsidian vault path defaults to the first vault in `~/.config/obsidian/obsidian.json`; Readest defaults to the Readest data dir under `~/.var/app/com.bilingify.readest/`. Both are overridable via `vaultPath` / `libraryPath` in the plugin entry of `~/.config/omarchy/shell.json`.

## Requirements (documented in each plugin README)

- All plugins require Omarchy quattro.
- `fd` + `jq` are preinstalled on Omarchy; search plugins list them as preinstalled requirements, not as install steps.
- focusd requires the `focusd` binary on `$PATH`.

## Publishing

- Bump `version` in a plugin's `manifest.json` — `publish.sh` skips a plugin if the remote manifest already matches the local version.
- Publish flow runs on push to `main` or `workflow_dispatch`; needs `PAT_TOKEN` (repo scope) set on the repo. Dry-run locally: `GITHUB_TOKEN=... bash scripts/publish.sh`.

## Environment notes

- Background daemons/commands can hang interactive tool shells — prefer `systemd-run --user` for long-lived watchers.
