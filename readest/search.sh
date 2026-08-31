#!/usr/bin/env bash
# Omarchy readest plugin: list searchable books from the Readest library.
# Emits one tab-delimited row per book: Title \t Author \t Book path \t Cover path.
# Filtering happens client-side (FuzzySearch.js), so every book is emitted.
# Results are sorted by most recently opened/updated.
#
# Usage: search.sh [LIBRARY_DIR]
# The library directory may be given as an argument; otherwise the default
# Pacman Readest data location is used.

home="$HOME"
lib_dir="${1:-}"
if [[ -z "$lib_dir" ]]; then
  lib_dir="$home/.local/share/com.bilingify.readest/Readest/Books"
fi
lib_dir="${lib_dir/#\~/$home}"
lib_json="$lib_dir/library.json"

[[ -f "$lib_json" ]] || exit 0

jq -r 'sort_by(.updatedAt // 0) | reverse | .[] | [.title, (.author // ""), .hash] | @tsv' "$lib_json" 2>/dev/null | while IFS=$'\t' read -r title author hash; do
  [[ -n "$title" && -n "$hash" ]] || continue

  book="$(fd -a -d1 -e epub -e pdf -e mobi -e azw3 . "$lib_dir/$hash" 2>/dev/null | head -n1)"
  [[ -n "$book" ]] || continue

  cover="$lib_dir/$hash/cover.png"
  [[ -f "$cover" ]] || cover=""

  printf '%s\t%s\t%s\t%s\n' "$title" "$author" "$book" "$cover"
done
