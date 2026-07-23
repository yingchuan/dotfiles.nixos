{ pkgs, ... }:

let
  databasePath = "/home/richard/gen-ui-hub/docs/hub.db";
  databaseDirectory = "/home/richard/gen-ui-hub/docs";
  backupRoot = "/home/richard/.local/share/gen-ui-hub-backup";
  replicaRoot = "${backupRoot}/litestream";
  metadataRoot = "/home/richard/.local/state/gen-ui-hub-litestream";
  rcloneConfig = "/home/richard/.config/rclone/rclone.conf";
  rcloneCache = "/home/richard/.cache/rclone";

  configFile = (pkgs.formats.yaml { }).generate "gen-ui-hub-litestream.yml" {
    logging = {
      level = "info";
      type = "text";
      stderr = true;
    };

    # Keep a week of recovery history. The rclone layer mirrors this retained
    # replica to Drive, so expired and compacted objects are removed remotely
    # only after a successful transfer pass.
    snapshot = {
      interval = "1h";
      retention = "168h";
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
      ExecStart = "${pkgs.rclone}/bin/rclone sync ${replicaRoot} gdrive-crypt: --config ${rcloneConfig} --cache-dir ${rcloneCache} --checkers 4 --transfers 2 --delete-after";

      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = "read-only";
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        rcloneConfig
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
