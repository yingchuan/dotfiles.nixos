{ ... }:

{
  # Desktop Environment
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;

  # COSMIC — enabled alongside GNOME. Both remain selectable as sessions
  # at the login screen; switch back to GNOME any time.
  services.desktopManager.cosmic.enable = true;

  # COSMIC's own greeter (cosmic-greeter) replaces GDM. It still lists all
  # installed sessions, so GNOME stays reachable from the session picker.
  services.displayManager.cosmic-greeter.enable = true;

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
