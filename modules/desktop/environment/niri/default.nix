{ inputs, ... }:
{
  flake.modules.nixos.desktop-niri = 
  { inputs, pkgs, ... }:
  {
    # imports = [
    #   inputs.niri.nixosModules.niri
    # ];
    # programs.niri.enable = true;

    # programs.dms-shell = {
    #   enable = true;
    #   package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    #   quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;

    #   systemd = {
    #     enable = true;             # Systemd service for auto-start
    #     restartIfChanged = true;   # Auto-restart dms.service when dms-shell changes
    #   };
      
    #   # Core features
    #   enableSystemMonitoring = true;     # System monitoring widgets (dgop)
    #   enableVPN = true;                  # VPN management widget
    #   enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
    #   enableAudioWavelength = false;      # Audio visualizer (cava)
    #   enableCalendarEvents = true;       # Calendar integration (khal)
    #   enableClipboardPaste = true;       # Pasting from the clipboard history (wtype)
    # };
  };

  flake.modules.homeManager.desktop-niri = 
  { inputs, pkgs, ...}:
  {
    imports = [
      inputs.dms.homeModules.dank-material-shell
      inputs.dms-plugin-registry.modules.default
      inputs.dms.homeModules.niri
      inputs.niri.homeModules.niri
    ];

    programs.dank-material-shell = {
      enable = true;
      quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;

      niri = {
        enableKeybinds = true; 
      };

      systemd = {
        enable = true;             # Systemd service for auto-start
        restartIfChanged = true;   # Auto-restart dms.service when dank-material-shell changes
      };

      # Core features
      enableSystemMonitoring = true;     # System monitoring widgets (dgop)
      dgop.package = inputs.dgop.packages.${pkgs.system}.default;
      enableVPN = true;                  # VPN management widget
      enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
      enableAudioWavelength = false;      # Audio visualizer (cava)
      enableCalendarEvents = true;       # Calendar integration (khal)
      enableClipboardPaste = true;       # Pasting items from the clipboard (wtype)

      settings = {
        theme = "dark";
        dynamicTheming = true;
        # Add any other settings here
      };

      session = {
        isLightMode = false;
        # Add any other session state settings here
      };

      clipboardSettings = {
        maxHistory = 25;
        maxEntrySize = 5242880;
        autoClearDays = 1;
        clearAtStartup = true;
        disabled = false;
        disableHistory = false;
        disablePersist = true;
      };

      managePluginSettings = true;
      plugins = {
        # Simply enable plugins by their ID (from the registry)
        dankBatteryAlerts.enable = true;
        dockerManager.enable = true;
        
        # Add plugin-specific settings
        mediaPlayer = {
          enable = true;

          # You can only define settings here if using the home-manager module
          settings = {
            preferredSource = "spotify";
          };
        };
      };
    };
    # systemd.user.services.niri-flake-polkit.enable = false;
  };
}
