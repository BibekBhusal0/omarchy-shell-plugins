# Readest for Omarchy

A keyboard-first overlay for fuzzy-searching your
[Readest](https://readest.com/) library and opening books with cover previews.

![Readest overlay preview](preview.png)

## Requirements

- Readest (Flatpak `com.bilingify.readest`) with a library at
  `~/.var/app/com.bilingify.readest/data/com.bilingify.readest/Readest/Books`
- `fd` and `jq`

## Library location

The library is read from the Flatpak data directory above by default. To use a
different location, add a `libraryPath` setting to the plugin entry in
`~/.config/omarchy/shell.json`:

```json
"plugins": [
  { "id": "readest", "libraryPath": "/path/to/your/books" }
]
```

## Install

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-readest.git --enable
```

## Use

Bind the overlay to a key (Hyprland `~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER", "R", "exec, omarchy-shell shell summon readest")
```

- Type to fuzzy-filter the library by title or author. Results are ranked, not
  just substring-matched.
- `Enter` opens the selected book in Readest; `Escape` closes.

## Uninstall

```bash
omarchy plugin remove readest
```

## Credits

Fuzzy matching uses [`FuzzySearch.js`](FuzzySearch.js), adapted from
[omarchy-raindrop-bookmarks](https://github.com/treramey/omarchy-raindrop-bookmarks)
by Trevor Ramey, licensed under the MIT License.

## License

This plugin is licensed under the [MIT License](../LICENSE).
