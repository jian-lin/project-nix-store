;;; project-nix-store-tests.el --- Test project-nix-store  -*- lexical-binding: t; -*-

;; SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;;; Code:

(require 'project-nix-store)
(require 'ert)
(require 'subr-x)
(eval-when-compile (require 'cl-lib))

(ert-deftest project-nix-store-try ()
  (let ((project-nix-store-dir "/nix/store/")
        (project-to-dirs
         '(nil
           ("/" "/nix" "/nix/store/"
            "/home/" "/home/me/" "/home/me/project/" "/home/me/project/nixpkgs/"
            "/root/" "/var/" "/var/lib/" "/tmp/")
           (nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/")
           ("/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/"
            "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/"
            "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/"
            "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/site-lisp/"
            "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/site-lisp/elpa/"
            "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/site-lisp/elpa/project-0.11.2/")
           (nix-store . "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/")
           ("/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/"
            "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/share/"
            "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/share/emacs/"
            "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/share/emacs/30.2/"
            "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/share/emacs/30.2/lisp/"
            "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/share/emacs/30.2/lisp/progmodes/"))))
    (cl-loop
     for (project dirs) on project-to-dirs by #'cddr
     do (ert-info ((format "%S" project) :prefix "project = ")
          (cl-loop
           for dir in dirs
           do (ert-info ((format "%S" dir) :prefix "dir = ")
                (let ((project-nix-store--cached-projects (make-hash-table :test 'equal)))
                  (ert-info ("run without cache")
                    (should (equal (project-nix-store-try dir)
                                   project)))
                  (ert-info ("cache is created")
                    (ert-info ((format "%S" project-nix-store--cached-projects)
                               :prefix "cache = ")
                      (should (equal (gethash dir project-nix-store--cached-projects)
                                     (or project 'not-found)))))
                  (ert-info ("run with cache")
                    (should (equal (project-nix-store-try dir)
                                   project))))))))))

(ert-deftest project-nix-store-root ()
  "Test `project-root' called with a project-nix-store instance."
  (let ((project-and-roots
         '((nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/")
           "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/"
           (nix-store . "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/")
           "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/")))
    (cl-loop for (project project-root) on project-and-roots by #'cddr
             do (ert-info ((format "%S" project) :prefix "project = ")
                  (should (equal (project-root project)
                                 project-root))))))

(ert-deftest project-nix-store-name ()
  "Test `project-name' called with a project-nix-store instance."
  (let ((project-nix-store-dir "/nix/store/")
        (project-and-name-suffixes
         '((nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/")
           "emacs-packages-deps"
           (nix-store . "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/")
           "emacs-30.2")))
    (cl-loop
     for (project project-name-suffix) on project-and-name-suffixes by #'cddr
     do (ert-info ((format "%S" project) :prefix "project = ")
          (cl-loop
           for project-nix-store-name-prefix in '("/NS/" "/nix-store/" "<nix-store>")
           do (ert-info ((format "%S" project-nix-store-name-prefix)
                         :prefix "project-nix-store-name-prefix = ")
                (let ((project-nix-store--cached-project-names (make-hash-table :test 'equal))
                      (project-name (concat project-nix-store-name-prefix
                                            project-name-suffix)))
                  (ert-info ("run without cache")
                    (should (equal (project-name project)
                                   project-name)))
                  (ert-info ("cache is created")
                    (ert-info ((format "%S" project-nix-store--cached-project-names)
                               :prefix "cache = ")
                      (should (equal (gethash (project-root project)
                                              project-nix-store--cached-project-names)
                                     project-name))))
                  (ert-info ("run with cache")
                    (should (equal (project-name project)
                                   project-name))))))))))

(cl-defstruct project-nix-store-tests--dummy-project-type
  "A dummy project type for test."
  root)

(ert-deftest project-nix-store-p ()
  (cl-loop for nix-store-project in
           '((nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/")
             (nix-store . "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/"))
           do (should (project-nix-store-p nix-store-project)))
  (cl-loop for non-nix-store-project in
           '((vc Git "~/code/fork/nixpkgs/")
             (transient . "~/code/fork/nixpkgs/")
             `(make-project-nix-store-tests--dummy-project-type :root "~/code/fork/nixpkgs/"))
           do (should-not (project-nix-store-p non-nix-store-project))))

(defmacro project-nix-store-tests-save-value (symbol &rest body)
  "Record SYMBOL's value; evaluate BODY in `progn'; restore SYMBOL's value.
SYMBOL should evaluate to a symbol.
SYMBOL can be unbound, i.e., its value is void."
  (declare (indent 1) (debug t))
  (cl-with-gensyms (is-bound original-value)
    (cl-once-only (symbol)
      `(let* ((,is-bound (boundp ',symbol))
              (,original-value (when ,is-bound
                                 (symbol-value ,symbol))))
         (unwind-protect
             (progn ,@body)
           (if ,is-bound
               (set ,symbol ,original-value)
             (makunbound ',symbol)))))))

(ert-deftest project-nix-store-unload-function ()
  (project-nix-store-tests-save-value 'project-find-functions
    (project-nix-store-tests-save-value 'project-list-exclude
      (add-hook 'project-find-functions #'project-nix-store-try -20)
      (add-hook 'project-list-exclude #'project-nix-store-p)
      (defvar project-find-functions)
      (defvar project-list-exclude)
      (ert-info ("hook functions are added")
        (should (memq #'project-nix-store-try project-find-functions))
        (should (memq #'project-nix-store-p project-list-exclude)))
      (ert-info ("return nil so that the standard unloading proceeds")
        ;; `project-nix-store-unload-function' is only called after 'loadhist is loaded
        (require 'loadhist)
        (should-not (project-nix-store-unload-function)))
      (ert-info ("hook functions are removed")
        (should-not (memq #'project-nix-store-try project-find-functions))
        (should-not (memq #'project-nix-store-p project-list-exclude))))))

(ert-deftest project-nix-store-dir-change-clear-cache ()
  "Test that cache is cleared after `project-nix-store-dir' is changed."
  (project-nix-store-tests-save-value 'project-nix-store-dir
    (let ((project-nix-store-dir "/nix/store/")
          (project-nix-store--cached-projects (make-hash-table :test 'equal))
          (project-nix-store--cached-project-names (make-hash-table :test 'equal)))
      (project-name
       (project-nix-store-try "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/"))
      (ert-info ("cache is created")
        (should-not (hash-table-empty-p project-nix-store--cached-projects))
        (should-not (hash-table-empty-p project-nix-store--cached-project-names)))
      (setopt project-nix-store-dir "/tmp/store/")
      (ert-info ("cache is cleared")
        (should (hash-table-empty-p project-nix-store--cached-projects))
        (should (hash-table-empty-p project-nix-store--cached-project-names))))))

(ert-deftest project-nix-store-name-prefix-change-clear-cache ()
  "Test cache is cleared after `project-nix-store-name-prefix' is changed."
  (project-nix-store-tests-save-value 'project-nix-store-name-prefix
    (let ((project-nix-store--cached-project-names (make-hash-table :test 'equal)))
      (project-name
       '(nix-store . "/nix/store/xxywqayx584zfal9d3h0smk5k2slyk44-emacs-30.2/"))
      (ert-info ("cache is created")
        (should-not (hash-table-empty-p project-nix-store--cached-project-names)))
      (setopt project-nix-store-name-prefix "<store>")
      (ert-info ("cache is cleared")
        (should (hash-table-empty-p project-nix-store--cached-project-names))))))

(ert-deftest project-nix-store-dir-change-value ()
  "Test that `project-nix-store-dir' can be changed by `setopt'."
  (project-nix-store-tests-save-value 'project-nix-store-dir
    (let ((new-value "/project/store/tests/"))
      (ert-info ("before change")
        (should-not (equal project-nix-store-dir
                           new-value)))
      (setopt project-nix-store-dir new-value)
      (ert-info ("after change")
        (should (equal project-nix-store-dir
                       new-value))))))

(ert-deftest project-nix-store-name-prefix-change-value ()
  "Test that `project-nix-store-name-prefix' can be changed by `setopt'."
  (project-nix-store-tests-save-value 'project-nix-store-name-prefix
    (let ((new-value "/project/store/tests/"))
      (ert-info ("before change")
        (should-not (equal project-nix-store-name-prefix
                           new-value)))
      (setopt project-nix-store-name-prefix new-value)
      (ert-info ("after change")
        (should (equal project-nix-store-name-prefix
                       new-value))))))

(provide 'project-nix-store-tests)

;;; project-nix-store-tests.el ends here

;; Local Variables:
;; package-lint-main-file: "project-nix-store.el"
;; End:
