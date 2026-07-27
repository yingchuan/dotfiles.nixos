{ pkgs, ... }:

let
  databasePath = "/home/richard/gen-ui-hub/docs/hub.db";
  databaseDirectory = "/home/richard/gen-ui-hub/docs";
  backupRoot = "/home/richard/.local/share/gen-ui-hub-backup";
  replicaRoot = "${backupRoot}/litestream";
  metadataRoot = "/home/richard/.local/state/gen-ui-hub-litestream";
  rcloneConfigDir = "/home/richard/.config/rclone";
  rcloneConfig = "${rcloneConfigDir}/rclone.conf";
  rcloneCache = "/home/richard/.cache/rclone";

  configFile = (pkgs.formats.yaml { }).generate "gen-ui-hub-litestream.yml" {
    logging = {
      level = "info";
      type = "text";
      stderr = true;
    };

    # Two days of recovery history. Each level-9 snapshot is a full copy of the
    # database (~43 MiB at 86 MiB on disk), so hourly snapshots cost roughly
    # 1 GiB per retained day, both locally and on Drive. A week of them measured
    # at 3.2 GiB after three days and was heading for ~7 GiB steady state, which
    # is why the window is 48h rather than 168h. The rclone layer mirrors this
    # retained replica to Drive, so expired and compacted objects are removed
    # remotely only after a successful transfer pass.
    snapshot = {
      interval = "1h";
      retention = "48h";
    };

    validation.interval = "6h";
    verify-compaction = true;

    dbs = [
      {
        path = databasePath;
        # Keep Litestream's mutable tracking state out of the application repo,
        # otherwise the default .hub.db-litestream directory dirties the tree.
        meta-path = metadataRoot;
        monitor-interval = "1s";
        checkpoint-interval = "1m";
        busy-timeout = "5s";
        replica = {
          path = replicaRoot;
          sync-interval = "1s";
        };
      }
    ];
  };
in
{
  environment.systemPackages = [
    pkgs.litestream
    pkgs.rclone
  ];

  # The service runs as richard because /home/richard is intentionally 0700.
  # Keep both runtime directories private; only replicaRoot is uploaded later.
  systemd.tmpfiles.rules = [
    "d ${backupRoot} 0700 richard users - -"
    "d ${replicaRoot} 0700 richard users - -"
    "d ${metadataRoot} 0700 richard users - -"
    "d ${rcloneCache} 0700 richard users - -"
  ];

  systemd.services.gen-ui-hub-litestream = {
    description = "Litestream local replica for gen-ui-hub";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];

    serviceConfig = {
      Type = "simple";
      User = "richard";
      Group = "users";
      UMask = "0077";
      ExecStartPre = "${pkgs.coreutils}/bin/test -r ${databasePath}";
      ExecStart = "${pkgs.litestream}/bin/litestream replicate -config ${configFile}";
      Restart = "on-failure";
      RestartSec = "5s";

      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = "read-only";
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        databaseDirectory
        replicaRoot
        metadataRoot
      ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RestrictSUIDSGID = true;
    };
  };

  systemd.services.gen-ui-hub-gdrive-backup = {
    description = "Upload the gen-ui-hub Litestream replica to encrypted Google Drive";
    after = [
      "gen-ui-hub-litestream.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      Group = "users";
      UMask = "0077";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/test -r ${rcloneConfig}"
        "${pkgs.coreutils}/bin/test -d ${replicaRoot}"
      ];
      # --drive-use-trash=false is scoped to this one sync command, which only
      # ever touches the dedicated gdrive-crypt: backing path. Without it Drive
      # moves every expired Litestream object to Trash, so the seven-day
      # retention above frees no quota at all. Nothing outside the backup tree
      # is reachable from here, so the user's own Trash is unaffected.
      ExecStart = "${pkgs.rclone}/bin/rclone sync ${replicaRoot} gdrive-crypt: --config ${rcloneConfig} --cache-dir ${rcloneCache} --checkers 4 --transfers 2 --delete-after --drive-use-trash=false";

      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = "read-only";
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      # The directory, not just the file: rclone persists a refreshed OAuth
      # token by writing rclone.conf<random> alongside it and renaming, so a
      # writable file inside a read-only directory is not enough. Without this
      # every run logged "Failed to save config ... read-only file system" and
      # the refreshed token was kept in memory only, which would silently break
      # the backup the first time Google rotated the refresh token.
      ReadWritePaths = [
        rcloneConfigDir
        rcloneCache
      ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictSUIDSGID = true;
    };
  };

  systemd.timers.gen-ui-hub-gdrive-backup = {
    description = "Periodically upload the gen-ui-hub Litestream replica";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "20m";
      Persistent = true;
      RandomizedDelaySec = "2m";
      Unit = "gen-ui-hub-gdrive-backup.service";
    };
  };
}
