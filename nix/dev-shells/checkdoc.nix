# SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
# SPDX-License-Identifier: GPL-3.0-or-later

{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      apps.checkdoc = {
        type = "app";
        meta.description = "Run Emacs checkdoc-batch function against Emacs lisp files";
        program = self'.checks.checkdoc;
      };

      checks.checkdoc = pkgs.writeShellApplication {
        name = "checkdoc";
        runtimeInputs = [
          pkgs.emacs
        ];
        text = ''
          for file in "$@"; do
            emacs --batch \
              --eval='(setq enable-local-variables :safe)' \
              --eval='(setq checkdoc-arguments-in-order-flag t)' \
              "$file" \
              --funcall=checkdoc-batch
          done
        '';
      };
    };
}
