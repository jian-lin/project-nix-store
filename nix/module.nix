# SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
# SPDX-License-Identifier: GPL-3.0-or-later

{ inputs, self, ... }:

let
  pname = "project-nix-store";
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages = {
        ${pname} = pkgs.emacs.pkgs.${pname};
      };

      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config = { };
      };
    };

  flake.overlays.default = _final: prev: {
    emacsPackagesFor =
      emacs:
      (prev.emacsPackagesFor emacs).overrideScope (
        efinal: _eprev: {
          ${pname} = efinal.callPackage ./_package.nix { };
        }
      );
  };
}
