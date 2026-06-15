{ ... }:

{
  # Desktop Environment (shared baseline: GNOME + GDM).
  # COSMIC is opt-in per host — see hosts/thinkpad-t14s-gen6 — and is
  # deliberately kept off x300m-stx (TV box, keep it simple).
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.printing.enable = true;

  # Sound (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
