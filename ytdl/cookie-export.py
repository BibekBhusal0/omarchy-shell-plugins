#!/usr/bin/env python3
"""Extract fresh Firefox-compatible cookies from a running browser profile.

Firefox-based browsers (zen, helium, glide) lock cookies.sqlite and keep live
cookie writes in the -wal file. yt-dlp's --cookies-from-browser only reads the
.sqlite file, so it misses fresh cookies and fails with "Sign in to confirm
you're not a bot" or "cookies no longer valid".

This merges sqlite+wal, dedupes keeping the newest cookie per (host, name),
filters to the target domain, and writes a clean cookies.sqlite that yt-dlp
can read. Call as:

  cookie-export.py <live-profile-dir> <out-dir> [host-filter]

Exits 0 and prints the out dir on success, nonzero on failure.
"""

import os
import shutil
import sqlite3
import sys

def main():
    if len(sys.argv) < 3:
        print("usage: cookie-export.py <profile-dir> <out-dir> [host-filter]", file=sys.stderr)
        return 2

    profile = os.path.abspath(sys.argv[1])
    outdir = os.path.abspath(sys.argv[2])
    host_filter = sys.argv[3] if len(sys.argv) > 3 else None

    db_src = os.path.join(profile, "cookies.sqlite")
    if not os.path.exists(db_src):
        print(f"no cookies.sqlite in {profile}", file=sys.stderr)
        return 1

    os.makedirs(outdir, exist_ok=True)
    db_tmp = os.path.join(outdir, "cookies.sqlite")
    shutil.copy2(db_src, db_tmp)

    # Copy the WAL too so uncommitted live cookies are included.
    for suffix in ("-wal", "-shm"):
        wal = db_src + suffix
        if os.path.exists(wal):
            try:
                shutil.copy2(wal, db_tmp + suffix)
            except OSError:
                pass

    # Merge WAL into the main DB, then discard stale duplicates.
    con = sqlite3.connect(db_tmp)
    con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    for suffix in ("-wal", "-shm"):
        p = db_tmp + suffix
        if os.path.exists(p):
            try:
                os.remove(p)
            except OSError:
                pass

    try:
        cols = [d[0] for d in con.execute("select * from moz_cookies limit 0").description]
    except sqlite3.OperationalError as e:
        print(f"cannot read {db_tmp}: {e}", file=sys.stderr)
        con.close()
        return 1

    rows = con.execute("select * from moz_cookies").fetchall()
    best = {}
    for r in rows:
        d = dict(zip(cols, r))
        if host_filter and host_filter not in d["host"]:
            continue
        key = (d["host"], d["name"])
        if key not in best or d["creationTime"] > best[key]["creationTime"]:
            best[key] = d

    con.execute("drop table moz_cookies")
    con.execute("""create table moz_cookies (
      id INTEGER PRIMARY KEY, originAttributes TEXT NOT NULL DEFAULT '',
      name TEXT NOT NULL, value TEXT NOT NULL, host TEXT NOT NULL, path TEXT NOT NULL,
      expiry INTEGER NOT NULL DEFAULT 0, isSecure INTEGER NOT NULL DEFAULT 0,
      isHttpOnly INTEGER NOT NULL DEFAULT 0, creationTime INTEGER NOT NULL DEFAULT 0,
      lastAccessed INTEGER NOT NULL DEFAULT 0, sameSite INTEGER NOT NULL DEFAULT 0)""")
    for d in best.values():
        con.execute(
            "insert into moz_cookies (name,value,host,path,expiry,isSecure,isHttpOnly,creationTime,lastAccessed,sameSite) values (?,?,?,?,?,?,?,?,?,?)",
            (d["name"], d["value"], d["host"], d["path"], d["expiry"], d["isSecure"],
             d["isHttpOnly"], d["creationTime"], d["lastAccessed"], d["sameSite"]))
    con.commit()
    con.close()
    print(outdir)
    return 0

if __name__ == "__main__":
    sys.exit(main())