# Omarchy Shell Plugin for Lock Screen

A custom lock screen service for Omarchy, cloned from the built-in `omarchy.lock`.

## Features

- Big customizable date and time display above the password input field
- Power action controls at the bottom for Shutdown, Restart, and Sleep
- Integrated MPRIS media widget showing currently playing track title, artist, and playback controls (previous, play/pause, next)
- Security prompt for "Forgot password" that alerts and blanks the screen
- Separate password and fingerprint PAM authentication flows

## Requirements

- Omarchy quattro

## Install

This is a personal clone of the built-in `omarchy.lock`; on this machine it lives in the shell plugin monorepo and is installed under the id `bibek.lock`. To install from the standalone repo on a fresh system:

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-lock.git --enable
```

## Configuration

Options can be customized under its entry in `~/.config/omarchy/shell.json`:

```json
{
  "plugins": [
    {
      "id": "bibek.lock",
      "timeFormat": "hh:mm AP",
      "dateFormat": "dddd, MMMM d"
    }
  ]
}
```

## Uninstall

```bash
omarchy plugin remove bibek.lock
```

## Credits

Lock screen service and layout adapted from the built-in `omarchy.lock` by the Omarchy team.

This plugin is licensed under the [MIT License](../LICENSE).

## Others

Here are my other Omarchy plugins:

- [Focusd](https://github.com/BibekBhusal0/omarchy-focusd) - pomodoro timer with streak, history and daily goal
- [Media](https://github.com/BibekBhusal0/omarchy-media) - MPRIS now-playing with playback controls
- [Obsidian Search](https://github.com/BibekBhusal0/omarchy-obsidian-search) - fuzzy-search your Obsidian vault
- [Readest](https://github.com/BibekBhusal0/omarchy-readest) - fuzzy-search your Readest library
- [yt-dlp](https://github.com/BibekBhusal0/omarchy-ytdl) - video downloads with progress and history

Please give a star if you find them useful!
