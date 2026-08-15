#!/usr/bin/env bash
# Publish each plugin folder in this repo to its own standalone repo.
#
# For every subfolder containing a manifest.json with a "homepage" pointing at
# <org>/<repo>, this script:
#   1. Reads the local plugin version.
#   2. Fetches the remote manifest.json version (same branch).
#   3. If different (or the repo does not exist yet), clones the target repo,
#      replaces its contents with the plugin folder, commits, pushes, and
#      creates a GitHub release tagged v<version>.
#
# Usage: GITHUB_TOKEN=... bash scripts/publish.sh
# Requires: git, jq, curl, gh
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
GITHUB_ACTOR="${GITHUB_ACTOR:-github-actions[bot]}"
BRANCH="${BRANCH:-main}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "GITHUB_TOKEN (or GH_TOKEN) is required" >&2
  exit 1
fi

git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$GITHUB_ACTOR@users.noreply.github.com"

log() { echo "==> $*"; }

publish_plugin() {
  local dir="$1"
  local manifest="$dir/manifest.json"
  local id version name description homepage
  id="$(jq -r '.id // empty' "$manifest")"
  version="$(jq -r '.version // empty' "$manifest")"
  name="$(jq -r '.name // empty' "$manifest")"
  description="$(jq -r '.description // empty' "$manifest")"
  homepage="$(jq -r '.homepage // empty' "$manifest")"

  [[ -n "$id" && -n "$version" ]] || {
    log "Skipping $dir: missing id or version"
    return 0
  }
  [[ -n "$homepage" && "$homepage" =~ ^https://github\.com/ ]] || {
    log "Skipping $dir: no github.com homepage in manifest"
    return 0
  }

  local repo_path="${homepage#https://github.com/}"
  repo_path="${repo_path%.git}"
  local org="${repo_path%%/*}"
  local repo="${repo_path##*/}"
  [[ -n "$org" && -n "$repo" && "$repo_path" != "$org" ]] || {
    log "Skipping $dir: bad homepage '$homepage'"
    return 0
  }

  log "$id v$version -> $org/$repo"

  # Create the repo if it doesn't exist yet.
  if ! gh api "repos/$org/$repo" >/dev/null 2>&1; then
    log "Creating $org/$repo"
    gh repo create "$org/$repo" --public --description "$description" \
      --homepage "$homepage" --confirm || {
      log "Could not create $org/$repo; skipping"
      return 0
    }
  fi

  # Compare with the remote version on the same branch.
  local remote_version=""
  remote_version="$(curl -fsSL "https://raw.githubusercontent.com/$org/$repo/$BRANCH/manifest.json" \
    2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
  if [[ -n "$remote_version" && "$remote_version" == "$version" ]]; then
    log "Up to date (remote v$remote_version); skipping"
    return 0
  fi
  log "Remote v${remote_version:-<none>} -> local v$version; publishing"

  local clone="$WORK/$repo"
  git clone --branch "$BRANCH" \
    "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$org/$repo.git" "$clone" \
    2>/dev/null || {
    log "Clone failed; trying default branch"
    git clone "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$org/$repo.git" "$clone" \
      2>/dev/null || {
      log "Clone failed for $org/$repo; skipping"
      return 0
    }
  }

  (cd "$clone" && git checkout -B "$BRANCH" 2>/dev/null || true)

  # Replace the repo contents with the plugin folder (excluding .git).
  (cd "$clone" && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +)
  cp -a "$dir/." "$clone/"

  local changed=0
  (cd "$clone" && git add -A && git diff --cached --quiet) || changed=1

  if [[ "$changed" == "1" ]]; then
    (cd "$clone" && git commit -m "Release v$version" && git push origin "$BRANCH")
    log "Pushed $org/$repo"
  else
    log "No content changes (version bump only not tracked); pushing anyway"
    (cd "$clone" && git push origin "$BRANCH")
  fi

  # Release (idempotent: skip if the tag already exists).
  if ! gh api "repos/$org/$repo/releases/tags/v$version" >/dev/null 2>&1; then
    gh release create "v$version" --repo "$org/$repo" \
      --title "$name v$version" --generate-notes
    log "Created release v$version"
  else
    log "Release v$version already exists; skipping"
  fi
}

for dir in "$ROOT"/*; do
  [[ -d "$dir" ]] || continue
  [[ -f "$dir/manifest.json" ]] || continue
  [[ "$(basename "$dir")" == scripts ]] && continue
  publish_plugin "$dir"
done

log "Done."
