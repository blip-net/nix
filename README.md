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

## Install (other distros, via Home Manager)

```nix
# Flake inputs
inputs.blip.url = "github:blip-net/nix";

# Home Manager configuration
imports = [ blip.homeModules.default ];
programs.blip.enable = true;
```
