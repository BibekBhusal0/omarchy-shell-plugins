# Omarchy Shell Plugin for Focusd

A beautiful [Focusd](https://github.com/BibekBhusal0/focusd) pomodoro timer for the Omarchy bar. Shows the current session and remaining time with a state icon, and opens a control panel with pause, skip, and stop actions plus your streak, sessions today, and progress toward the daily goal.

## Features

- Bar widget showing session state and remaining time
- Control panel with pause, skip, and stop
- Streak, daily goal, and sessions today from Focusd history
- Customizable state icons
- Switchable popup style (linear hero or circular face)

## Requirements

- Omarchy quattro
- [Focusd](https://github.com/BibekBhusal0/focusd)

## Install

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-focusd.git --enable
```

## Usage

Click the bar widget to open the control panel, or bind it to a key (`~/.config/hypr/bindings.lua`):

```lua
o.bind("CTRL", "T", "exec, omarchy-shell shell summon focusd")
```

Start the timer with `focusd start`.

## Configuration

Durations and presets are set in Focusd itself (`focusd settings`). The plugin's options go under its entry in `~/.config/omarchy/shell.json`.

Default configuration:

```json
"bar": {
  "layout": {
    "right": [
      {
        "id": "focusd",
        "progressBarStyle": "linear",
        "icons": {
          "work": "",
          "work-paused": "󰏤",
          "short-break": "",
          "short-break-paused": "󰏤",
          "long-break": "󰒲",
          "long-break-paused": "󰏤"
        }
      }
    ]
  }
}
```

`progressBarStyle` switches the popup between the `linear` and `circular`:

```json
"bar": {
  "layout": {
    "right": [
      { "id": "focusd", "progressBarStyle": "circular" }
    ]
  }
}
```

`icons` overrides the per-state bar icons. Any of the keys above can be replaced:

```json
"bar": {
  "layout": {
    "right": [
      {
        "id": "focusd",
        "icons": {
          "work": "🍅",
          "work-paused": "",
          "short-break": "☕",
          "short-break-paused": "",
          "long-break": "🏖️",
          "long-break-paused": ""
        }
      }
    ]
  }
}
```

Alternatives per state (pick the ones you like; `-paused` variants reuse the same pause icon or keep it same because the opacity is decreased):

| Key           | Suggestions   |
| ------------- | ------------- |
| `work`        | 󰅐, 󰀠, 🍅,    |
| `short-break` | ☕, 🍪, ,   |
| `long-break`  | 🏖️, ⏳, 🌴, 󰒲 |
| `paused`      | 󰏦, 󰏥, , 󰏤    |

## Uninstall

```bash
omarchy plugin remove focusd
```

## Credits

Bar widget and panel design adapted from [Omadoro](https://github.com/brianblakely/omadoro) by Brian Blakely, licensed under the MIT License.

This plugin is licensed under the [MIT License](../LICENSE).
