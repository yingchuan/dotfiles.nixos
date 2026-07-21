# gen-ui-hub encrypted backup

## Status

- `rclone` is installed declaratively on `thinkpad-t14s-gen6` through Home Manager.
- The local `gdrive:` and `gdrive-crypt:` remotes use a dedicated Google OAuth client and have
  passed an encrypted read/write/delete probe.
- The declarative x300m Litestream local-replica service is implemented but not deployed yet.
- The x300m upload timer and the production restore drill are not implemented yet.

Do not describe the backup as operational until the restore acceptance test below passes.

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

Use `rclone copy`, not `rclone sync`, for the first implementation so a configuration mistake
cannot delete remote history.

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

## Planned x300m units

The pinned Litestream 0.5 service is defined in `hosts/x300m-stx/litestream.nix`. It runs as
`richard` because `/home/richard` is intentionally mode `0700`, and writes only these runtime
locations:

- replica: `/home/richard/.local/share/gen-ui-hub-backup/litestream`;
- tracking metadata: `/home/richard/.local/state/gen-ui-hub-litestream`.

It keeps hourly snapshots for seven days, validates the replica every six hours, and keeps mutable
Litestream metadata outside the application repository. The service must be deployed and pass a
local restore drill before this increment is complete.

Remaining planned units:

- `gen-ui-hub-gdrive-backup.service` as `Type=oneshot`;
- `gen-ui-hub-gdrive-backup.timer` every 15 to 30 minutes with `Persistent=true`;
- optionally, a weekly restore-drill service and timer.

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
