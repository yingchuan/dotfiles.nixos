{ ... }:

{
  # Desktop Environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # COSMIC — enabled alongside GNOME so it can be tried as a session
  # choice at the GDM login screen without dropping GNOME. Pick "COSMIC"
  # from the gear menu on the login screen; switch back any time.
  services.desktopManager.cosmic.enable = true;

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
