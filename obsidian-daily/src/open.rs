//! Obsidian URI helpers and launching the desktop app.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use chrono::NaiveDate;

use crate::config::{Vault, VaultError};
use crate::status::Snapshot;
use crate::todos::{read_snapshot, resolved_note_path};

/// Build `obsidian://open?path=…` for an absolute note path.
pub fn open_uri(path: &Path) -> String {
    let abs = path.display().to_string();
    let encoded = percent_encode_path(&abs);
    format!("obsidian://open?path={encoded}")
}

fn percent_encode_path(value: &str) -> String {
    let mut out = String::with_capacity(value.len() * 3);
    for b in value.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b'/' => {
                out.push(b as char);
            }
            _ => {
                out.push('%');
                out.push(hex(b >> 4));
                out.push(hex(b & 0xf));
            }
        }
    }
    out
}

fn hex(n: u8) -> char {
    char::from(if n < 10 { b'0' + n } else { b'A' + (n - 10) })
}

/// Launch the URI via `xdg-open` (Omarchy / Wayland desktop).
pub fn launch(uri: &str) -> Result<(), VaultError> {
    // Some desktop handlers keep xdg-open alive until the app closes. Do not
    // hold up the frontend's action queue for the lifetime of Obsidian.
    Command::new("xdg-open")
        .arg(uri)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .map_err(|e| VaultError::Io(format!("failed to spawn xdg-open: {e}")))?;
    Ok(())
}

/// Open a wikilink / markdown-link target from a todo in Obsidian.
///
/// `target` is the raw link destination as written in the note (`[[Foo]]`
/// arrives here as `Foo`, `[text](../Bar.md)` as `../Bar.md`). External URLs
/// are refused: the shell opens those directly. Returns a snapshot of the
/// source day so the frontend action queue stays consistent.
pub fn open_link(vault: &Vault, date: NaiveDate, target: &str) -> Result<Snapshot, VaultError> {
    let path = resolve_link_target(vault, date, target)?;
    launch(&open_uri(&path))?;
    read_snapshot(vault, date)
}

/// Resolve a link target to a file inside the vault.
///
/// `#section` / `#^block` anchors are dropped (Obsidian is asked to open the
/// note itself). Dotted paths resolve against the source note's directory
/// first, then the vault root; bare names are searched vault-wide by
/// filename. Every candidate is canonicalized and must stay inside the vault.
fn resolve_link_target(
    vault: &Vault,
    date: NaiveDate,
    target: &str,
) -> Result<PathBuf, VaultError> {
    let raw = target.trim();
    if raw.is_empty() {
        return Err(VaultError::Io("empty link target".into()));
    }
    if raw.contains("://") {
        return Err(VaultError::Io(format!(
            "external links are opened by the shell: {raw:?}"
        )));
    }
    let config = vault.daily_notes_config()?;
    let note_path = resolved_note_path(vault, &config, date)?;
    // A section-only link (`[[#Heading]]`) points at the note itself.
    let base = raw.split('#').next().unwrap_or("").trim();
    if base.is_empty() {
        return Ok(note_path);
    }
    let base = base.strip_prefix("./").unwrap_or(base);
    if base.is_empty() {
        return Ok(note_path);
    }

    if base.contains('/') || base.starts_with('.') {
        let mut candidates = Vec::new();
        if let Some(dir) = note_path.parent() {
            push_with_md_ext(&mut candidates, dir.join(base));
        }
        push_with_md_ext(&mut candidates, vault.root().join(base.trim_start_matches('/')));
        let mut outside = false;
        for candidate in &candidates {
            if !candidate.is_file() {
                continue;
            }
            match contained_in_vault(vault.root(), candidate) {
                Some(path) => return Ok(path),
                None => outside = true,
            }
        }
        if outside {
            return Err(VaultError::Io(format!(
                "link target is outside the vault: {raw:?}"
            )));
        }
        return Err(VaultError::Io(format!("link target not found: {raw:?}")));
    }

    find_note_by_name(vault.root(), base)
        .and_then(|found| contained_in_vault(vault.root(), &found))
        .ok_or_else(|| VaultError::Io(format!("link target not found: {raw:?}")))
}

/// Push `path`, plus `path.md` when it has no extension.
fn push_with_md_ext(out: &mut Vec<PathBuf>, path: PathBuf) {
    if path.extension().is_none() {
        out.push(path.with_extension("md"));
    }
    out.push(path);
}

/// Search the vault for `<name>.md` by filename; the shallowest match wins,
/// with an exact-name hit preferred over a case-insensitive one. The walk is
/// bounded, skips dot-directories, and never follows symlinks.
fn find_note_by_name(root: &Path, name: &str) -> Option<PathBuf> {
    const MAX_DEPTH: u32 = 12;
    const MAX_ENTRIES: u64 = 20_000;
    let wanted = format!("{name}.md");
    let wanted_lower = wanted.to_lowercase();
    let mut exact: Option<PathBuf> = None;
    let mut fuzzy: Option<PathBuf> = None;
    let mut stack = vec![(root.to_path_buf(), 0u32)];
    let mut visited: u64 = 0;
    while let Some((dir, depth)) = stack.pop() {
        if depth > MAX_DEPTH || visited >= MAX_ENTRIES {
            break;
        }
        let entries = fs::read_dir(&dir).ok()?;
        for entry in entries.flatten() {
            visited += 1;
            if visited > MAX_ENTRIES {
                break;
            }
            let file_type = entry.file_type().ok()?;
            // Never follow symlinks: resolution must stay inside the vault.
            if file_type.is_symlink() {
                continue;
            }
            let path = entry.path();
            let fname = entry.file_name().to_string_lossy().into_owned();
            if fname.starts_with('.') {
                continue;
            }
            if file_type.is_dir() {
                if depth < MAX_DEPTH {
                    stack.push((path, depth + 1));
                }
            } else if fname == wanted {
                let shallower = match &exact {
                    Some(cur) => path.components().count() < cur.components().count(),
                    None => true,
                };
                if shallower {
                    exact = Some(path);
                }
            } else if fuzzy.is_none() && fname.to_lowercase() == wanted_lower {
                fuzzy = Some(path);
            }
        }
    }
    exact.or(fuzzy)
}

/// Canonicalize `candidate` and accept it only when it stays inside `root`.
fn contained_in_vault(root: &Path, candidate: &Path) -> Option<PathBuf> {
    let root = root.canonicalize().ok()?;
    let resolved = candidate.canonicalize().ok()?;
    resolved.starts_with(&root).then_some(resolved)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn link_fixture(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "obsidian-daily-qs-link-{name}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(dir.join("Projects")).unwrap();
        fs::create_dir_all(dir.join("Daily")).unwrap();
        fs::write(dir.join("2026-09-29.md"), "- [ ] today\n").unwrap();
        fs::write(dir.join("Projects").join("Foo.md"), "# Foo\n").unwrap();
        fs::write(dir.join("Projects").join("foo.md"), "# lowercase\n").unwrap();
        fs::write(dir.join("Daily").join("2026-09-29.md"), "- [ ] nested\n").unwrap();
        dir
    }

    fn fixture_vault(dir: &Path) -> Vault {
        Vault::from_path(dir).unwrap()
    }

    fn date() -> NaiveDate {
        NaiveDate::from_ymd_opt(2026, 9, 29).unwrap()
    }

    #[test]
    fn resolves_bare_name() {
        let dir = link_fixture("bare");
        let vault = fixture_vault(&dir);
        let found = resolve_link_target(&vault, date(), "Foo").unwrap();
        assert_eq!(found, dir.join("Projects").join("Foo.md"));
    }

    #[test]
    fn resolves_bare_name_case_insensitively() {
        let dir = link_fixture("ci");
        let vault = fixture_vault(&dir);
        // `FOO` matches `foo.md` only when no exact hit exists; `Foo.md`
        // sits next to it so an exact-name search for `foo` wins first.
        let found = resolve_link_target(&vault, date(), "foo").unwrap();
        assert_eq!(found, dir.join("Projects").join("foo.md"));
        let _ = fs::remove_file(dir.join("Projects").join("foo.md"));
        let found = resolve_link_target(&vault, date(), "FOO").unwrap();
        assert_eq!(found, dir.join("Projects").join("Foo.md"));
    }

    #[test]
    fn drops_section_anchor() {
        let dir = link_fixture("anchor");
        let vault = fixture_vault(&dir);
        let found = resolve_link_target(&vault, date(), "Foo#Some Heading").unwrap();
        assert_eq!(found, dir.join("Projects").join("Foo.md"));
    }

    #[test]
    fn resolves_vault_relative_path() {
        let dir = link_fixture("rel");
        let vault = fixture_vault(&dir);
        let found = resolve_link_target(&vault, date(), "Projects/Foo").unwrap();
        assert_eq!(found, dir.join("Projects").join("Foo.md"));
    }

    #[test]
    fn missing_target_errors() {
        let dir = link_fixture("missing");
        let vault = fixture_vault(&dir);
        assert!(resolve_link_target(&vault, date(), "Nope").is_err());
        assert!(resolve_link_target(&vault, date(), "").is_err());
        assert!(resolve_link_target(&vault, date(), "https://example.com").is_err());
    }

    #[test]
    fn escape_attempt_errors() {
        let dir = link_fixture("escape");
        let vault = fixture_vault(&dir);
        // `..` from the vault root cannot stay inside the vault.
        assert!(resolve_link_target(&vault, date(), "../outside").is_err());
    }
    #[test]
    fn encodes_spaces_in_path() {
        let uri = open_uri(Path::new("/vault/Daily Notes/2026-08-20.md"));
        assert!(uri.starts_with("obsidian://open?path="));
        assert!(uri.contains("Daily%20Notes"));
        assert!(uri.contains("/2026-08-20.md"));
    }

    #[test]
    fn keeps_slashes() {
        let uri = open_uri(&PathBuf::from("/home/u/vault/a/b.md"));
        assert_eq!(uri, "obsidian://open?path=/home/u/vault/a/b.md");
    }
}
