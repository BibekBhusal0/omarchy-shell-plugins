# Focusd for Omarchy

A Focusd pomodoro timer for the Omarchy bar. Shows the current session and
remaining time with a state icon, and opens a keyboard-driven control panel
when clicked. The panel also shows your current streak, sessions completed
today, and progress toward your daily goal — straight from Focusd's history.
The bar label dims while the timer is paused.

![Focusd bar widget preview](preview.png)

## Requirements

- [Focusd](https://github.com/BibekBhusal0/focusd) installed and on `$PATH`
  (the daemon is started automatically by the CLI)

## Install

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-focusd.git --enable
```

## Use

The bar widget lands in the right section by default. Click it to open the
control panel.

| Button    | Action                                              |
| --------- | --------------------------------------------------- |
| `󰏤` / `` | Pause or resume the session                         |
| `󰒭`       | Skip to the next session                            |
| `󰛉`       | Stop the session (shown once a session has started) |

Start the timer from the bar with `SUPER + P` (or the CLI: `focusd start`),
or bind the pomodoro popup to a key, e.g. `CTRL + SUPER + T`.

The popup shows your current session, remaining time, and a stats section with
your streak (󰔟), focused time today, daily goal (󰓾), and sessions today ().
The daily-goal value only fills in when a goal is set in `focusd settings`.

## Progress bar style

The popup defaults to a linear hero with a progress bar. You can switch to the
circular timer face with the `progressBarStyle` setting in
`~/.config/omarchy/shell.json`:

```json
"bar": {
  "layout": {
    "right": [
      { "id": "focusd", "progressBarStyle": "circular" }
    ]
  }
}
```

## Bar icons

The bar label combines a per-state icon with the remaining time. Icons default
to Focusd's waybar icons:

| State                | Icon | Meaning             |
| -------------------- | ---- | ------------------- |
| `work`               | ``  | Working             |
| `work-paused`        | `󰏤`  | Work session paused |
| `short-break`        | ``  | Short break         |
| `short-break-paused` | `󰏤`  | Short break paused  |
| `long-break`         | `󰒲`  | Long break          |
| `long-break-paused`  | `󰏤`  | Long break paused   |

Customize them in `~/.config/omarchy/shell.json` under the plugin entry:

```json
"bar": {
  "layout": {
    "right": [
      { "id": "focusd", "icons": { "work": "󰅐", "long-break": "󰠌" } }
    ]
  }
}
```

## Keyboard controls

With the panel open:

- Use the arrow keys or `h`, `j`, `k`, and `l` to select a button.
- Press Enter or Space to activate it.
- Press Escape to close the panel.
- Press Tab or Shift+Tab to move between bar panels.

You can also open the popup from a terminal or your own keybinding:

```bash
omarchy-shell shell summon focusd
```

## Customize

Durations and presets are configured through Focusd itself:

```bash
focusd settings
```

## Uninstall

```bash
omarchy plugin remove focusd
```

## Credits

The bar widget design, `CircularProgress.qml`, panel, and keyboard-navigation
layout are adapted from [Omadoro](https://github.com/brianblakely/omadoro) by
Brian Blakely, licensed under the MIT License.

## License

This plugin is licensed under the [MIT License](../LICENSE).
