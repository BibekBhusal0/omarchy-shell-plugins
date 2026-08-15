#!/usr/bin/env bash
# Omarchy readest plugin: list searchable books from the Readest library.
# Emits one tab-delimited row per book: Title \t Author \t Book path \t Cover path.
# Filtering happens client-side (FuzzySearch.js), so every book is emitted.

home="$HOME"
lib_dir="$home/.var/app/com.bilingify.readest/data/com.bilingify.readest/Readest/Books"
lib_json="$lib_dir/library.json"

[[ -f "$lib_json" ]] || exit 0

jq -r '.[] | [.title, (.author // ""), .hash] | @tsv' "$lib_json" 2>/dev/null | while IFS=$'\t' read -r title author hash; do
  [[ -n "$title" && -n "$hash" ]] || continue

  book="$(fd -a -d1 -e epub -e pdf -e mobi -e azw3 . "$lib_dir/$hash" 2>/dev/null | head -n1)"
  [[ -n "$book" ]] || continue

  cover="$lib_dir/$hash/cover.png"
  [[ -f "$cover" ]] || cover=""

  printf '%s\t%s\t%s\t%s\n' "$title" "$author" "$book" "$cover"
done
