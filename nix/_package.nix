# SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
# SPDX-License-Identifier: GPL-3.0-or-later

{
  melpaBuild,
  lib,
}:

let
  pname = "project-nix-store";
in
melpaBuild {
  inherit pname;
  version =
    let
      parsedVersion = parse (lib.path.append ../. "${pname}.el");
      parse =
        file:
        file
        |> lib.readFile
        |> lib.match versionRegex
        |> (parsed: if parsed == null then null else lib.head parsed);
      # a simple and good enough regex
      versionRegex = ".*;; Version: ([[:digit:]]+(.[[:digit:]]+)*)\n.*";
    in
    lib.throwIfNot (parsedVersion != null) "${pname}: fail to parse version" parsedVersion;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.fileFilter (file: file.hasExt "el") ../.;
  };
  files = ''("*.el")''; # do not exclude test files

  # run tests in nix build
  doInstallCheck = true;
  postInstallCheck = ''
    emacs --batch \
      --funcall=package-activate-all \
      --eval "
        (let ((default-directory \"$out/share/emacs/site-lisp\"))
          (normal-top-level-add-subdirs-to-load-path))" \
      --load=${pname}-tests \
      --funcall=ert-run-tests-batch-and-exit

    lintEachFile() {
      find $out/share/emacs \
        -type f -name '*.el' \
        -not -name "*-pkg.el" -not -name "*-autoloads.el" -not -name ".dir-locals.el" \
        -print0 \
      | xargs --verbose -0 -I {} -n 1 -P "$NIX_BUILD_CORES" "$@"
    }

    lintEachFile \
      emacs --batch \
        --funcall=package-activate-all \
        "{}" \
        --eval='
          (progn
            ;; load indentation settings, if any, see (info "(emacs) Lisp Indent")
            (eval-buffer)
            (indent-region (point-min) (point-max))
            (with-current-buffer
                (diff-no-select buffer-file-name (current-buffer) nil t)
              (goto-char (point-min))
              (condition-case nil
                  (search-forward "Diff finished (no differences)")
                (search-failed
                 (princ (buffer-string))
                 (error "%s" "File indentation is wrong")))))'
  '';

  turnCompilationWarningToError = true;
}
