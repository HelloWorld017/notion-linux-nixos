# notion-linux-nixos
This project exists for using Notion in NixOS.
This is port of the [AUR / notion-app-electron](https://aur.archlinux.org/packages/notion-app-electron) in nix.

## Usage
```nix
# 1. Add `notion-linux` to the flake input
notion-linux = {
    url = "github:HelloWorld017/notion-linux-nixos";
    inputs.nixpkgs.follows = "nixpkgs";
};

# 2. Use the package
inputs.notion-linux.packages.${system}.default
```

## Disclaimer
This project is neither an official product nor affiliated with Notion Labs.
This is just bunch of hacks to run their app in NixOS.

## Warning
It does run, but actually it just runs and does not run perfectly.
