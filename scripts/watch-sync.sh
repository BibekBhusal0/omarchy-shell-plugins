#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

inotifywait -m -r -q -e close_write,create,delete,move \
  --format '%w%f' \
  "$REPO_DIR"/focusd "$REPO_DIR"/obsidian-search "$REPO_DIR"/readest "$REPO_DIR"/ytdl "$REPO_DIR"/media "$REPO_DIR"/lock |
while IFS= read -r path; do
  rel="${path#$REPO_DIR/}"
  [[ "$rel" == */* ]] || continue
  plugin="${rel%%/*}"
  dest_rel="${rel#*/}"
  dest="$PLUGINS_DIR/$plugin/$dest_rel"

  case "$rel" in
    *.qml|*.js|*.json|*.sh|ytdl/scripts/*) ;;
    *) continue ;;
  esac

  if [[ ! -e "$path" ]]; then
    rm -rf "$dest"
    echo "removed $dest (source deleted: $path)"
    continue
  fi

  if [[ -d "$path" ]]; then
    mkdir -p "$dest"
    echo "synced dir $path -> $dest"
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest"
  echo "synced $path -> $dest"
done
