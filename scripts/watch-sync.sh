#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

inotifywait -m -r -q -e close_write,create,delete,move \
  --format '%w%f' \
  "$REPO_DIR"/focusd "$REPO_DIR"/obsidian-search "$REPO_DIR"/readest "$REPO_DIR"/ytdl "$REPO_DIR"/media |
while IFS= read -r path; do
  case "$path" in
    *.qml|*.js|*.json|*.sh|*/ytdl)
      plugin="$(basename "$(dirname "$path")")"
      cp "$path" "$PLUGINS_DIR/$plugin/"
      echo "synced $path -> $PLUGINS_DIR/$plugin/"
      ;;
  esac
done
