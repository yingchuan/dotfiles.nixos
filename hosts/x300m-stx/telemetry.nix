{ ... }:

# Single-node trace backend for gen-ui-hub.
#
# Deliberately minimal: no OpenTelemetry Collector, no Grafana, no Kafka. The
# application speaks OTLP/HTTP JSON straight at VictoriaTraces, which is one
# Go binary with a built-in UI. Anything more is infrastructure we would then
# have to keep alive for a single-user hub.
#
# Privacy: traces carry only allowlisted attributes (see telemetry.go in the
# application), but they are still operational data about a private system, so
# the listener is bound to loopback and never proxied by nginx. Reach the UI
# over the WireGuard link with an SSH tunnel:
#
#   ssh -L 10428:127.0.0.1:10428 gen-ui-hub.duckdns.org
#   http://127.0.0.1:10428/select/vmui

{
  services.victoriatraces = {
    enable = true;
    # Loopback only. This is the security boundary for the whole subsystem.
    listenAddress = "127.0.0.1:10428";
    # Traces are for debugging a regression that just happened, not an audit
    # log. Two weeks is long enough to compare against "last week it was fine"
    # and short enough that the on-disk cost stays trivial.
    retentionPeriod = "14d";
  };
}
