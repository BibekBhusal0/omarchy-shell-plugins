## New Features

- Open search scoped to a specific vault: `omarchy-shell shell summon bibek.obsidian-search '{"vaultPath":"/path/to/vault"}'`. Pass an absolute vault path, so you can bind different keys to different vaults. Paths starting with `~` resolve against your home directory.

## Fixes

- The "Today's daily note" pin no longer shows in vaults where daily notes are disabled. It previously appeared there and opened a dead link.
