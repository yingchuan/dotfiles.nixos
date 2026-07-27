# gen-ui-hub encrypted backup

## Status

- `rclone` is installed declaratively on `thinkpad-t14s-gen6` through Home Manager.
- The local `gdrive:` and `gdrive-crypt:` remotes use a dedicated Google OAuth client and have
  passed an encrypted read/write/delete probe.
- The declarative x300m Litestream local-replica service is deployed and active.
- The first production local restore drill passed on 2026-07-21.
- The x300m encrypted Drive upload timer is deployed and active.
- The first encrypted Drive round-trip restore drill passed on 2026-07-21.
- Deletions are permanent as of 2026-07-27; expired objects no longer accumulate in Drive Trash.
- Snapshot retention is 48 hours, not seven days; see "Retention sizing".

The backup is durable off-machine and has passed both local-replica and encrypted Drive
round-trip restore drills.

## Architecture

```text
/home/richard/gen-ui-hub/docs/hub.db (SQLite WAL)
    -> Litestream continuous file replica
/home/richard/.local/share/gen-ui-hub-backup/litestream
    -> periodic rclone sync --delete-after --drive-use-trash=false
       through gdrive-crypt
Google Drive: gdrive-crypt:
    -> encrypted backing path
Google Drive: gdrive:gen-ui-hub/litestream
```

Litestream, rather than rclone, reads the live SQLite database and its WAL. Do not copy the live
database or WAL directly with rclone, and do not place the database on an rclone/FUSE mount.

The initial acceptance phase used `rclone copy` so a configuration mistake could not delete remote
history. After both local and Drive round-trip restore drills passed, the operational policy moved
to `rclone sync --delete-after`: Drive mirrors Litestream's validated local replica and does not
retain objects that Litestream has expired or replaced through compaction.

`--delete-after` alone did not free any Drive quota, because rclone's Drive backend moves deletions
to Trash by default. The sync command therefore also passes `--drive-use-trash=false`. That flag is
scoped to this single command, which can only reach the dedicated `gdrive-crypt:` backing path, so
it cannot affect anything the user deletes elsewhere in Drive.

## Retention sizing

Litestream level-9 LTX files are full snapshots of the database, not increments. At an 86 MiB
`hub.db` each one is about 43 MiB, so hourly snapshots cost roughly 1 GiB per retained day, both in
the local replica and on Drive.

The original seven-day window was therefore heading for about 7 GiB steady state. Measured on
2026-07-27, three days after the retention reset: local replica 3.5 GiB across 10,503 files, of
which `ltx/9` alone was 3.2 GiB across 79 snapshots.

The window is now 48 hours with the hourly granularity kept, which settles at 48 snapshots and
about 2 GiB. Revisit this if `hub.db` grows substantially; the cost scales with database size times
retained hours.

## rclone remotes

- `gdrive:` uses the `drive` backend with full `drive` scope and a dedicated Desktop OAuth client.
  Full scope is required because Google revokes `drive.file` authorization for previously created
  children after app deauthorization, which prevents reliable retention cleanup. The remote is
  operationally constrained to the dedicated `gen-ui-hub/litestream` backing path.
- `gdrive-crypt:` uses the `crypt` backend and points to
  `gdrive:gen-ui-hub/litestream`.
- Standard filename encryption and directory-name encryption are enabled.
- The crypt password and salt are randomly generated and stored only in the protected rclone
  configuration.

The OAuth client's Google Cloud project must have the Google Drive API enabled. If the consent
screen remains in testing mode, the backup account must be registered as a test user.

## Secrets

The operational configuration is:

```text
/home/richard/.config/rclone/rclone.conf
```

It must be owned by `richard` with mode `0600`. Never commit the file or copy any of these values
into Nix expressions, documentation, issue trackers, logs, or chat:

- OAuth client secret;
- access or refresh token;
- crypt password or salt, including rclone-obscured values.

`rclone obscure` is reversible obfuscation, not encryption. Treat the whole configuration file as
a secret and keep a separate secure recovery copy. Losing both the configuration and its crypt
credentials makes the encrypted backup unrecoverable.

Transfer only the minimal configuration to x300m over an authenticated channel, then enforce:

```sh
chmod 600 /home/richard/.config/rclone/rclone.conf
```

Do not store this file in Git or the Nix store.

## x300m units

The pinned Litestream 0.5 service is defined in `hosts/x300m-stx/litestream.nix`. It runs as
`richard` because `/home/richard` is intentionally mode `0700`, and writes only these runtime
locations:

- replica: `/home/richard/.local/share/gen-ui-hub-backup/litestream`;
- tracking metadata: `/home/richard/.local/state/gen-ui-hub-litestream`.

It keeps hourly snapshots for 48 hours, validates the replica every six hours, and keeps mutable
Litestream metadata outside the application repository.

The deployed upload path uses:

- `gen-ui-hub-gdrive-backup.service` as `Type=oneshot`;
- `gen-ui-hub-gdrive-backup.timer` every 20 minutes with `Persistent=true` and up to two minutes
  of randomized delay;
- `rclone sync --delete-after --drive-use-trash=false`, so remote deletion happens only after a
  successful transfer pass and actually frees quota;
- rclone's normal high-level retries to tolerate Litestream compaction replacing an LTX file
  between directory enumeration and file open.

`ReadWritePaths` must grant the rclone configuration *directory*, not just `rclone.conf`. rclone
persists a refreshed OAuth token by writing `rclone.conf<random>` beside the original and renaming
over it, which a writable file inside a read-only directory cannot satisfy. When this was wrong the
unit still succeeded, because the refreshed access token was held in memory, but it logged
`Failed to save config after 10 tries: ... read-only file system` on every run and would have
failed silently the first time Google rotated the refresh token.

A weekly restore-drill service and timer remain optional future work.

The upload unit must copy the Litestream replica, never the live `hub.db`.

## Restore acceptance test

Before calling the backup operational:

1. Confirm Litestream is continuously updating the local replica.
2. Upload the replica through `gdrive-crypt:`.
3. Download it through `gdrive-crypt:` into a fresh temporary directory.
4. Run `litestream restore` to a new temporary `hub.db`; never overwrite production.
5. Require the following check to return `ok`:

   ```sh
   sqlite3 -readonly /tmp/REPLACE_WITH_DRILL_DIR/hub.db 'PRAGMA integrity_check;'
   ```

6. Compare representative row counts for chat, memory, episode, and audiobook tables with the
   source database.
7. Record the last successful replication and restore-drill timestamps.

Production configuration changes must be developed and committed on `thinkpad-t14s-gen6`.
`x300m-stx` may only receive clean commits with `git pull --ff-only` followed by the normal NixOS
validation and switch workflow.

## Verification record

### 2026-07-21 local replica and restore drill

- First successful snapshot: `2026-07-21T11:16:54+08:00`.
- Restore completed: `2026-07-21T11:17:53+08:00`.
- Restored size: `79,777,792` bytes.
- `PRAGMA integrity_check`: `ok`.
- `PRAGMA foreign_key_check`: zero violations.
- Source/restored row counts matched for `sessions`, `chat_messages`, `memory_event`, `fact`,
  `episode`, `audiobook_book`, and `audiobook_chapter`.
- The restored database was created under a fresh `/tmp` directory and removed after validation;
  production `hub.db` was never overwritten.

### 2026-07-21 encrypted Drive round-trip restore drill

- First timer-driven upload started: `2026-07-21T11:31:58+08:00`.
- Upload completed successfully: `2026-07-21T11:33:39+08:00`.
- During the first pass, Litestream compaction replaced several enumerated LTX files. Rclone's
  second high-level attempt re-enumerated the replica and completed successfully; the systemd
  service exited with status zero.
- The encrypted replica was downloaded through `gdrive-crypt:` to a fresh temporary directory.
- Drive round-trip restore completed: `2026-07-21T11:35:26+08:00`.
- Restored size: `79,794,176` bytes.
- `PRAGMA integrity_check`: `ok`.
- `PRAGMA foreign_key_check`: zero violations.
- Source/restored row counts matched for `sessions`, `chat_messages`, `memory_event`, `fact`,
  `episode`, `audiobook_book`, and `audiobook_chapter`.
- Litestream and gen-ui-hub remained active, and the local application endpoint returned HTTP
  200.
- The restored database was never substituted for production `hub.db`; the temporary download
  and restored database were deleted after validation.

### 2026-07-24 seven-day retention reset and restore drill

- Before reset, the local replica had grown to `3,064,282,461` bytes and `8,732` files; Drive had
  retained compacted and expired objects because the initial upload policy used `rclone copy`.
- Backup timer, upload service, and Litestream were stopped before deletion.
- The local Litestream replica, Litestream tracking metadata, and dedicated `gdrive-crypt:` root
  were cleared. Production `hub.db` was never deleted, stopped, or overwritten.
- The Google OAuth scope was changed from `drive.file` to `drive`. The narrower scope could upload
  but returned `appNotAuthorizedToChild` while deleting objects created before reauthorization,
  making remote retention unreliable.
- Litestream restarted from TXID `0000000000000001`; its first new replica was approximately
  `127.5` MB with 17 files.
- The first baseline `rclone sync --delete-after` completed on its third high-level attempt.
  Google Drive temporarily rate-limited several uploads, and a concurrent Litestream compaction
  replaced one enumerated LTX file. Rclone did not delete remote objects during failed attempts and
  re-enumerated successfully.
- Drive round-trip download started: `2026-07-24T04:07:22+08:00`.
- Restore completed: `2026-07-24T04:09:08+08:00`.
- Restored size: `83,677,184` bytes.
- `PRAGMA integrity_check`: `ok`.
- `PRAGMA foreign_key_check`: zero violations.
- Source/restored row counts matched for `sessions`, `chat_messages`, `memory_event`, `fact`,
  `episode`, `audiobook_book`, and `audiobook_chapter`.
- Litestream, the upload timer, and gen-ui-hub remained active; local HTTP returned 200.
- The temporary download and restored database were deleted after validation.

### 2026-07-27 permanent deletion, 48-hour retention, and restore drill

Trash accounting before any deletion, cross-checked three ways:

- `rclone about gdrive:` reported `Trashed: 3.006 GiB`.
- A recursive count over the whole drive returned 39,905 trashed objects / 3.006 GiB.
- Recursing from the backup folder id returned 39,903 objects / 3.006 GiB, plus 2 objects / 106 B
  in a second, empty `gen-ui-hub` folder at drive root.
- 39,903 + 2 = 39,905, so every trashed object belonged to the backup tree and no unrelated user
  file was at risk.

Note that `--drive-trashed-only` filters files but not directory listings; a trashed and a live
directory of the same name are indistinguishable in `lsf` output. Scope by folder id instead, which
is what made the accounting above conclusive.

Effect of `--drive-use-trash=false` plus the 48-hour window, measured across the change:

| measurement            | before               | after                |
| ---------------------- | -------------------- | -------------------- |
| local replica          | 3.5 GiB / 10,503     | 2.1 GiB / 6,410      |
| `ltx/9` full snapshots | 79                   | 48                   |
| Drive backup tree      | 3.450 GiB / 10,459   | 2.009 GiB / 6,399    |
| Drive `Used`           | 14.740 GiB           | 13.299 GiB           |
| Drive `Trashed`        | 3.006 GiB            | 3.006 GiB, unchanged |

The 1.441 GiB released by expiry did not appear in Trash, which is the direct evidence that
deletion is now permanent. Under the previous behaviour `Used` would have stayed flat while
`Trashed` grew.

The pre-existing 3.006 GiB of trashed backup objects was then cleared with `rclone cleanup gdrive:`
after the accounting above established that the trash contained nothing else. Google empties the
trash asynchronously and took hours to work through roughly 40,000 objects.

Drive round-trip restore drill on the 48-hour chain:

- Download started `2026-07-27T10:36:39+08:00`, completed `2026-07-27T11:01:19+08:00`
  (2.1 GiB, 6,436 files; the long tail is many small LTX objects, one Drive API call each).
- Restore completed `2026-07-27T11:01:19+08:00`.
- Restored size: `86,183,936` bytes.
- `PRAGMA integrity_check`: `ok`.
- `PRAGMA foreign_key_check`: zero violations.
- Source/restored row counts matched for `sessions` (419), `chat_messages` (1242), `memory_event`
  (800), `fact` (101), `episode` (0), `audiobook_book` (2), and `audiobook_chapter` (318).
- Litestream, the upload timer, and gen-ui-hub remained active; local HTTP returned 200.
- Production `hub.db` was never overwritten; the temporary directory was removed after validation.
