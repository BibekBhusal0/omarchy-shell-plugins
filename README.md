# Omarchy Shell Plugins

Third-party plugins for the [Omarchy](https://omarchy.org/) shell. Each folder is a standalone shell plugin installable into `~/.config/omarchy/plugins/<plugin-id>/`.

## Plugins

| Plugin                                | ID                | Kind          | What it does                                             |
| ------------------------------------- | ----------------- | ------------- | -------------------------------------------------------- |
| [`focusd`](focusd/)                   | `focusd`          | bar-widget    | Circular Focusd pomodoro timer in the bar with a control panel |
| [`obsidian-search`](obsidian-search/) | `obsidian-search` | overlay       | Fuzzy-search Obsidian vault notes, create new notes      |
| [`readest`](readest/)                 | `readest`         | overlay       | Fuzzy-search the Readest library and open books          |

Each plugin ships its own `README.md` with install, usage, and credits.

## Install

Copy (or symlink) a folder into the user plugin directory, then rescan:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r readest ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
```

For a bar widget, enable it so it lands in the bar:

```bash
omarchy plugin enable focusd
```

Or install from git (each folder is a valid plugin repo root):

```bash
omarchy plugin add https://github.com/bibekbhusal0/omarchy-focusd.git --enable
```

Enable / disable:

```bash
omarchy plugin enable readest
omarchy plugin disable readest
omarchy plugin list
```

## Usage

Bar widgets appear directly in the bar (focusd defaults to the right section).
Overlays are summoned via the shell IPC:

```bash
omarchy-shell shell summon readest
omarchy-shell shell summon obsidian-search
```

To make overlays hotkey-accessible, bind them in Hyprland (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER", "R", "exec, omarchy-shell shell summon readest")
o.bind("SUPER", "O", "exec, omarchy-shell shell summon obsidian-search")
```

Or add rows pointing at them in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"readest":   {"icon": "󰂚", "label": "Readest",   "action": "omarchy-shell shell summon readest"},
"obsidian":  {"icon": "󰙮", "label": "Obsidian",  "action": "omarchy-shell shell summon obsidian-search"},
```

## Requirements

- `fd`, `jq` (obsidian-search, readest search scripts)
- Obsidian with a vault configured at `~/.config/obsidian/obsidian.json`
- Readest (Flatpak `com.bilingify.readest`) with a library at `~/.var/app/com.bilingify.readest/data/com.bilingify.readest/Readest/Books`
- Focusd installed and on `$PATH`

## Development

Validate a plugin folder against the shell's manifest schema before publishing:

```bash
omarchy plugin validate ./readest
```

The QML files run inside the long-lived `omarchy-shell` Quickshell process; edits under `~/.config/omarchy/plugins/` hot-reload on save.

## Publishing each plugin to its own repo

Each plugin also lives in its own standalone repo (listed in its `manifest.json` `homepage`). Pushing a new version of a plugin here publishes it to its own repo and cuts a `v<version>` release automatically.

Add a personal access token (repo scope) as the `PAT_TOKEN` secret, then either push to `main` or run the workflow manually:

```bash
# locally, to dry-run the logic (requires gh + token):
GITHUB_TOKEN=... bash scripts/publish.sh
```

## Credits

- focusd's bar widget design is adapted from [Omadoro](https://github.com/brianblakely/omadoro) (MIT) by Brian Blakely.
- obsidian-search and readest use [`FuzzySearch.js`](https://github.com/treramey/omarchy-raindrop-bookmarks) (MIT) by Trevor Ramey.
