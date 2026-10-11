# Blip for Nix

A Nix flake packaging [Blip](https://blip.net). Linux only.

## Try without installing

```sh
nix run github:blip-net/nix
```

## Install (NixOS)

```nix
# Flake inputs
inputs.blip.url = "github:blip-net/nix";

# NixOS configuration
imports = [ blip.nixosModules.default ];
programs.blip.enable = true;
```

## Install (Home Manager)

```nix
# Flake inputs
inputs.blip.url = "github:blip-net/nix";

# Home Manager configuration
imports = [ blip.homeModules.default ];
programs.blip.enable = true;
```

## Autostart

Both modules enable autostart by default. To disable it while keeping Blip installed, set:

```nix
programs.blip.autostart.enable = false;
```

Apply the change with your usual NixOS rebuild or Home Manager switch. Module installations
manage autostart through Nix; Blip's "Launch at login" setting explains that it is externally
managed. Package-only installations, including `nix run` and `nix profile`, use Blip's own
startup setting instead.

## Upgrading existing installations

The modules do not automatically migrate an existing app-created autostart entry or its
previous enabled/disabled preference. Before the first activation of the new modules:

1. Quit Blip from its tray menu.
2. If you previously disabled autostart and want to keep it disabled, set
   `programs.blip.autostart.enable = false` in your configuration.
3. Move the old app-created entry out of the way, if it exists:

   ```sh
   blip_autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/net.blip.Blip.desktop"
   if [ -f "$blip_autostart" ] && [ ! -L "$blip_autostart" ]; then
     mv -i -- "$blip_autostart" "$blip_autostart.before-nix"
   fi
   ```

   Home Manager otherwise refuses to replace the existing file. For the NixOS module,
   a per-user entry overrides the system-wide entry and can prevent the Nix option from
   taking effect. Keep entries already managed by Home Manager in place.
4. Update the Blip input with `nix flake update blip` in your configuration directory,
   then rebuild NixOS or switch Home Manager as usual. Use your input's name if it is
   different from `blip`.
5. If you also installed Blip separately with `nix profile`, remove that old package after
   successful activation. Find its entry name with `nix profile list`, then run
   `nix profile remove <entry-name>`.

To verify autostart, sign out and log back in without launching Blip manually. With autostart
enabled, Blip should appear in the tray without opening its main window. To test disabling it,
set the option to `false`, apply the configuration, and repeat that login test.
