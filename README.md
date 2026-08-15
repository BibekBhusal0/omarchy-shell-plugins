# Omarchy Shell Plugins

Third-party plugins for the [Omarchy](https://omarchy.org/) shell. Each folder is a standalone shell plugin installable into `~/.config/omarchy/plugins/<plugin-id>/`.

## Plugins

| Plugin                                | ID                | What it does                                             |
| ------------------------------------- | ----------------- | -------------------------------------------------------- |
| [`focusd`](focusd/)                   | `focusd`          | Control the Focusd pomodoro timer from an overlay picker |
| [`obsidian-search`](obsidian-search/) | `obsidian-search` | Fuzzy-search Obsidian vault notes, create new notes      |
| [`readest`](readest/)                 | `readest`         | Search the Readest library and open books                |

## Install

Each plugin is self-contained. Copy (or symlink) the folder into the user plugin directory, then rescan:

```bash
# e.g. for the readest plugin
mkdir -p ~/.config/omarchy/plugins
cp -r readest ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
```

Or install from git (each folder is a valid plugin repo root, so you can point `omarchy plugin add` at any subfolder URL):

```bash
omarchy plugin add https://github.com/bibekbhusal0/omarchy-shell-plugin/tree/main/readest --enable
```

Enable / disable:

```bash
omarchy plugin enable readest
omarchy plugin disable readest
omarchy plugin list
```

## Usage

Summon a plugin's overlay via the shell IPC:

```bash
omarchy-shell shell summon readest
omarchy-shell shell summon obsidian-search
omarchy-shell shell summon focusd
```

To make them hotkey-accessible, bind them in Hyprland (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER", "R", "exec, omarchy-shell shell summon readest")
o.bind("SUPER", "O", "exec, omarchy-shell shell summon obsidian-search")
o.bind("SUPER", "P", "exec, omarchy-shell shell summon focusd")
```

Or add rows pointing at them in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"readest":   {"icon": "󰂚", "label": "Readest",   "action": "omarchy-shell shell summon readest"},
"obsidian":  {"icon": "󰙮", "label": "Obsidian",  "action": "omarchy-shell shell summon obsidian-search"},
"focusd":    {"icon": "󰃰", "label": "Focusd",    "action": "omarchy-shell shell summon focusd"},
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
