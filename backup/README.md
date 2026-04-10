# Backup

A family of backup scripts covering three MySQL servers, the Confluence application data directory, and NAS-to-NAS mirroring. All database scripts share the same three-host rotation pattern and Telegram notification convention — they evolved independently on different servers but follow the same design.

## Files

| File | Description |
|------|-------------|
| `mysql-backup1.sh` | `mysqldump` each database individually then one combined full dump → gzip → scp to 3 hosts; Telegram on full dump only |
| `mysql-backup2.sh` | `mysqlpump` per-database + full server dump → gzip → scp to 3 hosts; drops root privilege at startup; flushes tables with read lock |
| `confluence-backup.sh` | `rsync` of Confluence attachments and index + `mysqldump` of confluence and visit databases → scp to 2 hosts; Telegram per database |
| `nas-backup.sh` | NAS-to-NAS mirror: mounts each share from nas2, rsyncs it, unmounts, repeats for 20 directories |

## How it works

### Rotation pattern (mysql-backup1.sh, mysql-backup2.sh)

Both scripts use a shared `copy_archive()` function. For each archive it iterates the three backup hosts, SCPs the file, then immediately runs:

```sh
ssh $Host "cd $Path && rm -f \$(ls -t1 *$ToRemove | tail -n +5)"
```

`ToRemove` is the filename with the date prefix stripped (`${Source#*_}`), leaving e.g. `expenses.gz`. The remote `ls -t1` lists all archives matching that suffix in reverse-time order; `tail -n +5` skips the four newest and pipes the rest to `rm -f`. This keeps exactly four copies per dataset on each host without any date arithmetic — recency is determined by filesystem mtime.

### Per-database then full dump (mysql-backup.sh)

`mysql-backup1.sh` dumps each database separately first (small archives, easier to restore a single DB), then dumps all of them together into one combined archive. Telegram notification fires only for the combined full dump, via a `TelegramSend=false` flag flipped to `true` just before the final `copy_archive` call. This avoids a flood of notifications on a successful run.

### mysqlpump vs mysqldump (mysql2-backup.sh)

`mysql-backup2.sh` uses `mysqlpump` (the parallel replacement for mysqldump) with `--complete-insert --users --add-drop-database` flags. It also calls a bare `mysqlpump` with no arguments to produce the full server dump — relying on the default behaviour of dumping everything — then gzips the resulting `db.sql`. The script wraps the entire dump window with `FLUSH TABLES WITH READ LOCK` / `UNLOCK TABLES` for consistency.

### Privilege drop (mysql2-backup.sh)

The script checks if it is running as root and if so re-executes itself as `<ADMIN_USER>` via `sudo -H -u <ADMIN_USER> $0`. This means it can be placed in `cron.daily` (which runs as root) without storing credentials or SSH keys under the root account — all SSH keys and MySQL credentials live in the user's home directory.

### Confluence application backup (confluence-backup.sh)

In addition to database dumps, `confluence-backup.sh` uses `rsync` with a strict include/exclude list to copy only the three meaningful paths from the Confluence data directory — `attachments/`, `index/`, and `confluence.cfg.xml` — to a local mount, skipping Confluence's own internal temp files and caches. The database side uses `--single-transaction` (no table lock) since Confluence's MySQL tables are InnoDB.

### NAS-to-NAS mirror (nas-backup.sh)

`nas-backup.sh` mounts each of 20 named shares from nas2 one at a time over NFS, rsyncs the contents, then unmounts before moving to the next. It uses 10-second and 30-second sleeps between operations — a pragmatic throttle to avoid overwhelming the NAS with back-to-back NFS mounts. There is no error handling; if a mount fails the `if mount ...; then` guard skips the rsync silently.

## Notable patterns

**`${Source#*_}` for rotation key extraction.** Stripping the date prefix from the archive filename with a single parameter expansion gives a stable suffix (e.g. `expenses.gz`) that matches all historical archives for the same dataset on the remote host. The rotation command `ls -t1 *$ToRemove | tail -n +5 | xargs rm -f` is then purely time-ordered — no date parsing, no regex, no external tools.

**`TelegramSend` flag flipped just before final archive.** Rather than checking whether the current archive is the last one inside the loop, both mysql scripts set `TelegramSend=false` before the loop and flip it to `true` after. The `copy_archive` function reads the flag on each call. This is a clean way to send exactly one notification per run without passing extra arguments to the function.

**`${Host#*@}` for readable Telegram messages.** When constructing the Telegram notification text, `${Host#*@}` strips the username prefix from `admin@192.168.5.200`, leaving just the IP for the message. The same variable is used both for SSH/SCP commands (needs `user@host`) and for human-readable output (needs just the host) without storing them separately.

**`exec sudo -H -u user $0` for privilege drop.** Re-executing the script as a different user via `exec` replaces the current process — there is no parent shell left running as root. `$0` is the script's own path, so the mechanism is entirely self-contained. Combined with `-H` (which sets `HOME` to the target user's home directory), SSH keys and MySQL credentials are transparently available without any path manipulation.

**`FLUSH TABLES WITH READ LOCK` without `mysqldump --lock-all-tables`.** `mysql-backup2.sh` issues the lock as a standalone `mysql -e` command before the `mysqlpump` loop, then unlocks after. This gives a single consistent lock window across all databases rather than one lock per database, which is safer for cross-database foreign key consistency. The trade-off is that the application is locked for the full duration of all dumps combined.

**`rsync --include/--exclude` for selective Confluence backup.** The include list (`attachments/***`, `index/***`, `confluence.cfg.xml`) uses the `***` pattern which matches the directory itself and all contents recursively. The trailing `--exclude '*'` drops everything else. This is the correct rsync pattern for a whitelist — include specific paths first, then exclude the catch-all. Reversing the order would exclude everything.

**`--single-transaction` for InnoDB hot backup.** `confluence-backup.sh` uses `--single-transaction` instead of `--lock-all-tables`. For InnoDB tables this takes a consistent snapshot via a transaction start, allowing reads and writes to continue during the dump. It is incompatible with MyISAM tables but appropriate for Confluence's schema.

**NFS mount/unmount loop as a sequential throttle.** `nas-backup.sh` never has more than one share mounted at a time. By mounting, syncing, and unmounting in sequence with sleep gaps, it avoids the memory and file descriptor overhead of 20 simultaneous NFS mounts. The `if mount ...; then rsync; fi` guard also means a temporarily unavailable share is silently skipped rather than aborting the whole run.

**Three scripts, one rotation algorithm.** All three MySQL backup scripts implement the same `ls -t1 | tail -n +5` rotation independently — no shared library, no helper script. The algorithm is simple enough to copy verbatim. This is a good example of the point where shared infrastructure would add complexity rather than remove it.
