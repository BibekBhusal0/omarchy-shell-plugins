# Omarchy Shell Plugin for Obsidian Daily

Today's [Obsidian](https://obsidian.md/) daily-note todos in the Omarchy bar. Shows done/total for today and opens a panel to check, add, carry over and defer items, with extra checkbox states, cascade checking and full keyboard navigation.

## Features

- Bar widget with today's done/total and one-click panel
- Checkbox states beyond open/done: half-done `[/]`, canceled `[-]`, forwarded `[>]` and more, cycled with `;` (`:` goes backward)
- Cascade checking: checking a parent checks every subtask, completing all subtasks completes the parent
- Full keyboard navigation across day buttons, week strip, tools, checkboxes and the add button
- Week strip day jumping, search, open-only filter, sort orders, carry-over, undo, open in Obsidian
- Clickable links: `[[wikilinks]]`, `[text](path)` and bare URLs open in Obsidian (vault notes) or the browser (http links)

## Differences from upstream

Forked from [LucaNerlich/obsidian-daily-qs](https://github.com/LucaNerlich/obsidian-daily-qs) (`luca.obsidian-daily`, Apache-2.0). Kept as-is: daily-note resolution, templates, archive folder, carry-over, defer, undo, sorting, search, and all bar settings.

Changed in this fork:

- **No bar color or ring.** The widget always renders in the normal bar text color. Errors still surface through the label (`!`) and tooltip.
- **Extended todo states.** Any single-character marker parses. Only ` ` (open), `-` (canceled) and `/` (half-done) count as not done; everything else counts as done. `;` cycles ` ` → `/` → `x` → `-` → `>` → `<` → `?` → `!` → `*` → `"` → `l` → `b` → `i` → `I` → `p` → `c` → `f` → `k` → `u` → `d` → back to ` `, `:` walks it backward.
- **Cascade checking.** Toggling a parent stamps the same marker onto every subtask. Each ancestor then recomputes from its direct children: all done → done, all open/canceled → open, anything mixed → half-done. Works at any nesting depth, in one write (one undo).
- **Zone keyboard navigation.** Up/Down (or `j`/`k`) move across rows, Left/Right (or `h`/`l`) move inside a row. Inside a todo, Left/Right flips between the checkbox (Enter/Space toggles) and the delete button. `[`/`]` switch days, `{`/`}` outdent/indent. `Esc` in any field just leaves the field so keys work again; `Tab`/`Shift-Tab` switches panels even from inside inputs.

## Requirements

- Omarchy quattro
- Obsidian with the Daily notes core plugin configured
- Rust toolchain (only to build the backend once: `cargo build --release`)
- `x86_64` or `aarch64` Linux

## Install

No standalone repo exists yet, so install from this monorepo:

```bash
ln -sfn ~/Code/omarchy-shell-plugins/obsidian-daily ~/.config/omarchy/plugins/obsidian-daily
cd ~/Code/omarchy-shell-plugins/obsidian-daily && cargo build --release
cp target/release/obsidian-daily-qs omarchy/bin/obsidian-daily-qs-$(uname -m)
```

Then register `{"id": "bibek.obsidian-daily"}` in `~/.config/omarchy/shell.json` (plugins array, plus `bar.layout.right` for the widget) and restart the shell:

```bash
omarchy-restart-shell
```

Set the vault path once:

```bash
omarchy bar set bibek.obsidian-daily vaultPath '/home/you/Documents/vault'
```

## Usage

Left-click opens the panel, middle/right-click opens the note in Obsidian. The panel starts in the add field: type and Enter to add, `Shift+Enter` to nest under the selected todo, `Esc` to drive everything from the keyboard.

Shortcuts: arrows or `h`/`j`/`k`/`l` to move, Enter/Space to activate, `;`/`:` to cycle the todo state forward/backward, `t` for today, `a`/`+` to add, `e` to edit, `x` to delete, `{`/`}` to outdent/indent, `[`/`]` for previous/next day, `/` to search, `u` to undo, `Esc` to close (or leave a field first).

## Configuration

Settings live in the plugin entry of `~/.config/omarchy/shell.json` (edits apply live):

```bash
omarchy bar set bibek.obsidian-daily openOnly true
omarchy bar set bibek.obsidian-daily sortOrder newest
omarchy bar set bibek.obsidian-daily todoHeading Todos
omarchy bar set bibek.obsidian-daily insertHeading Inbox
```

- `vaultPath`: vault directory. Overrides `OBSIDIAN_VAULT_ROOT`.
- `archiveFolder`: folder pattern for moved old notes (e.g. `dailies/_archive/YYYY`).
- `openOnly`: hide completed checkboxes when the panel opens. Default `false`.
- `sortOrder`: `default`, `newest`, `openFirst`, `alphabetical`. Default `default`.
- `todoHeading`: only show todos under this heading. Empty = all todos.
- `insertHeading`: heading new todos go under. Empty = follow `todoHeading`, then `Tasks`/`Todos`.
- `hideWhenDone` / `hideWhenEmpty`: conceal the bar widget when done or empty. Default `false`.

## Uninstall

```bash
omarchy plugin remove bibek.obsidian-daily
```

## Credits

Backend, panel structure and week/carry-over logic forked from [obsidian-daily-qs](https://github.com/LucaNerlich/obsidian-daily-qs) by Luca Nerlich, licensed under the Apache-2.0 License (see [`LICENSE`](LICENSE)). This fork's modifications (states, cascade checking, keyboard zones, bar cleanup) are under the same license.

This plugin is licensed under the [Apache-2.0 License](LICENSE).

## Others

Here are my other Omarchy plugins:

- [Focusd](https://github.com/BibekBhusal0/omarchy-focusd) - pomodoro timer with streak, history and daily goal
- [Obsidian Search](https://github.com/BibekBhusal0/omarchy-obsidian-search) - fuzzy-search your Obsidian vault
- [Readest](https://github.com/BibekBhusal0/omarchy-readest) - fuzzy-search your Readest library
- [Youtube Video Downloader](https://github.com/BibekBhusal0/omarchy-ytdl) - video downloads with progress and history
- [Better Lock](https://github.com/BibekBhusal0/omarchy-better-lock) - lock screen with date/time, media and power controls
- [Better Media](https://github.com/BibekBhusal0/omarchy-better-media) - MPRIS now-playing with playback controls
- [Better Menu](https://github.com/BibekBhusal0/omarchy-better-menu) - fuzzy menu with app grid, calculator and web search

Please give a star if you find them useful!
