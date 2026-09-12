# SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
# SPDX-License-Identifier: GPL-3.0-or-later

{ inputs, ... }:

{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    {
      self',
      ...
    }:
    {
      pre-commit = {
        settings.hooks = {
          # keep-sorted start block=yes
          actionlint = {
            enable = true;
            args = [
              # this new self-repository syntax was added in 2026-07-30
              # actionlint doesn't support it: https://github.com/rhysd/actionlint/issues/711
              # ignore its error for now
              ''-ignore=reusable workflow call "\$/.+" at "uses" is not following the format''
            ];
          };
          checkLocalLinks = {
            enable = true;
            name = "Check local links";
            entry = self'.apps.check-links.program;
            args = [
              "--no-progress"
              "--offline"
            ];
            types = [ "text" ];
            language = "unsupported";
          };
          checkdoc = {
            enable = true;
            name = "checkdoc";
            entry = self'.apps.checkdoc.program;
            files = "\\.el$";
            types = [ "text" ];
            excludes = [
              "^\\.dir-locals\\.el$"
            ];
            language = "unsupported";
          };
          package-lint = {
            enable = true;
            name = "package-lint";
            entry = self'.apps.package-lint.program;
            files = "\\.el$";
            types = [ "text" ];
            excludes = [
              "^\\.dir-locals\\.el$"
            ];
            language = "unsupported";
          };
          reuse.enable = true;
          treefmt.enable = true;
          zizmor = {
            enable = true;
            entry = self'.apps.zizmor.program;
            args = [
              "--no-progress"
            ];
            files = "^\\.github/(dependabot\\.|actions/|workflows/)";
          };
          # keep-sorted end
        };
      };
    };
}
