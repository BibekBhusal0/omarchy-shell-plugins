# Omarchy Shell Plugin for Media

An MPRIS now-playing widget for the Omarchy bar, cloned from the built-in `omarchy.media`, plus support for the [cliamp](https://github.com/bjarneo/cliamp) headless daemon.

Shows the playing track with a play/pause glyph in the bar, and opens a popup with album art, previous/play-pause/next buttons, and a list of active media sources to switch between.

## Features

- Bar widget with play/pause state and "title · artist" (truncated with `…` when too long)
- Popup with album art, transport controls, and source switching
- Full MPRIS support for any player (Spotify, browsers, etc.)
- [cliamp](https://github.com/bjarneo/cliamp) headless daemon support (`cliamp --daemon`, no MPRIS bridge needed)
- IPC target `media` for scripts and hotkeys

## Requirements

- Omarchy quattro
- `cliamp` on `PATH` (only for cliamp support)

`fd` and `jq` are not required by this plugin.

## Install

This is a personal clone of the built-in `omarchy.media`; on this machine it lives in the shell plugin monorepo and is installed under the id `bibek.media`. To install from the standalone repo on a fresh system:

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-media.git --enable
```

## Usage

The bar widget appears automatically while something is playing:

| Action | Effect |
| ------ | ------ |
| Left click | Play/pause |
| Middle click | Next track |
| Right click | Toggle the popup |
| Scroll up / down | Previous / next track |

### IPC

```bash
omarchy-shell media status
omarchy-shell media playPause
omarchy-shell media next
omarchy-shell media previous
omarchy-shell media sourceNext
omarchy-shell media sourcePrevious
```

## cliamp headless

[Headless daemon mode](https://github.com/bjarneo/cliamp/blob/main/docs/headless.md) runs cliamp with no TUI and no MPRIS bridge. The plugin polls `cliamp status --json` over cliamp's IPC socket and exposes the daemon as a media source, so the bar widget, popup, and `omarchy-shell media ...` commands all control it.

Start the daemon (e.g. as a systemd user unit or login autostart):

```bash
cliamp --daemon
```

The daemon and the widget share one source: while a cliamp MPRIS player is present the CLI player is skipped, so there is never a duplicate cliamp entry in the source list.

## Uninstall

```bash
omarchy plugin remove bibek.media
```

## Credits

Bar widget and service adapted from the built-in `omarchy.media` by the Omarchy team.

This plugin is licensed under the [MIT License](../LICENSE).
