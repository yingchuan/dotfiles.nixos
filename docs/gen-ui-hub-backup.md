# gen-ui-hub encrypted backup

## Status

- `rclone` is installed declaratively on `thinkpad-t14s-gen6` through Home Manager.
- The local `gdrive:` and `gdrive-crypt:` remotes use a dedicated Google OAuth client and have
  passed an encrypted read/write/delete probe.
- The declarative x300m Litestream local-replica service is deployed and active.
- The first production local restore drill passed on 2026-07-21.
- The x300m encrypted Drive upload timer is deployed and active.
- The first encrypted Drive round-trip restore drill passed on 2026-07-21.

The backup is durable off-machine and has passed both local-replica and encrypted Drive
round-trip restore drills.

## Architecture

```text
/home/richard/gen-ui-hub/docs/hub.db (SQLite WAL)
    -> Litestream continuous file replica
/home/richard/.local/share/gen-ui-hub-backup/litestream
    -> periodic rclone copy through gdrive-crypt
Google Drive: gdrive-crypt:
    -> encrypted backing path
Google Drive: gdrive:gen-ui-hub/litestream
```

Litestream, rather than rclone, reads the live SQLite database and its WAL. Do not copy the live
database or WAL directly with rclone, and do not place the database on an rclone/FUSE mount.

The initial acceptance phase used `rclone copy` so a configuration mistake could not delete remote
history. After both local and Drive round-trip restore drills passed, the operational policy moved
to `rclone sync --delete-after`: Drive mirrors Litestream's validated seven-day local replica and
does not retain objects that Litestream has expired or replaced through compaction.

## rclone remotes

- `gdrive:` uses the `drive` backend with `drive.file` scope and a dedicated Desktop OAuth client.
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

It keeps hourly snapshots for seven days, validates the replica every six hours, and keeps mutable
Litestream metadata outside the application repository.

The deployed upload path uses:

- `gen-ui-hub-gdrive-backup.service` as `Type=oneshot`;
- `gen-ui-hub-gdrive-backup.timer` every 20 minutes with `Persistent=true` and up to two minutes
  of randomized delay;
- `rclone sync --delete-after`, so remote deletion happens only after a successful transfer pass;
- rclone's normal high-level retries to tolerate Litestream compaction replacing an LTX file
  between directory enumeration and file open.

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
