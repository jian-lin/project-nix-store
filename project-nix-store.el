;;; project-nix-store.el --- Project backend for Nix-like store  -*- lexical-binding: t; -*-

;; SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
;; SPDX-License-Identifier: GPL-3.0-or-later

;; Author: Lin Jian <me@linj.tech>
;; URL: https://github.com/jian-lin/project-nix-store
;; Keywords: nix nix-store project tools
;; Version: 0.9.0
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; Refer to README or `describe-package'.

;;; Code:

(eval-when-compile (require 'cl-lib))

(defgroup project-nix-store ()
  "Project backend for Nix-like store."
  :group 'project
  :prefix "project-nix-store-"
  :link '(url-link
          :tag "Nix store"
          "https://nix.dev/manual/nix/2.35/store/index.html")
  :link '(info-link "(emacs) Projects"))

(defvar project-nix-store--cached-projects (make-hash-table :test 'equal)
  "Cache for `project-nix-store-try'.")

(defvar project-nix-store--cached-project-names (make-hash-table :test 'equal)
  "Cache for `project-name'.")

(defun project-nix-store--set-dir (symbol value)
  "Set `project-nix-store-dir' after invalidating cache.
SYMBOL and VALUE are passed to `set-default-toplevel-value'.
VALUE is preprocessed by `file-name-as-directory'."
  (clrhash project-nix-store--cached-projects)
  (clrhash project-nix-store--cached-project-names)
  (set-default-toplevel-value symbol (file-name-as-directory value)))

(defcustom project-nix-store-dir "/nix/store/"
  "Store directory.

See URL `https://nix.dev/manual/nix/2.35/store/store-path.html#store-directory-path'."
  :type 'directory
  ;; TODO set :initialize when Emacs bug#81396 is fixed
  ;; :initialize #'custom-initialize-changed
  :set #'project-nix-store--set-dir
  :link '(url-link
          :tag "store directory definition"
          "https://nix.dev/manual/nix/2.35/store/store-path.html#store-directory-path"))

;;;###autoload
(defun project-nix-store-try (dir)
  "Return a store project instance of DIR.
DIR should be a store path or a child dir of a store path.
Otherwise, return nil.

See `project-root' for store path definition."
  (let ((cached-project (with-memoization
                            (gethash dir project-nix-store--cached-projects)
                          (or (project-nix-store--try-without-cache dir)
                              ;; `with-memoization' can't distinguish nil and "no value yet".
                              ;; Use symbol `not-found' to represent nil.
                              'not-found))))
    (unless (eq cached-project 'not-found)
      cached-project)))

(defun project-nix-store--try-without-cache (dir)
  "Like `project-nix-store-try', but do not use cache.
See `project-nix-store-try' for DIR and return value."
  (when (and (string-prefix-p project-nix-store-dir dir)
             (not (string= dir project-nix-store-dir)))
    (cl-loop for project-root = dir then project-root-parent
             for project-root-parent = (file-name-parent-directory project-root)
             until (string= project-root-parent project-nix-store-dir)
             finally return (cons 'nix-store project-root))))

(cl-defmethod project-root ((project (head nix-store)))
  "Return PROJECT store path.

See URL `https://nix.dev/manual/nix/2.35/store/store-path.html#store-path'
for store path definition."
  (cdr project))

(defun project-nix-store--set-name-prefix (symbol value)
  "Set `project-nix-store-name-prefix' after invalidating cache.
SYMBOL and VALUE are passed to `set-default-toplevel-value'."
  (clrhash project-nix-store--cached-project-names)
  (set-default-toplevel-value symbol value))

(defcustom project-nix-store-name-prefix "/NS/"
  "Prefix of `project-name' for store projects."
  :type 'string
  ;; TODO set :initialize when Emacs bug#81396 is fixed
  ;; :initialize #'custom-initialize-changed
  :set #'project-nix-store--set-name-prefix)

(cl-defmethod project-name ((project (head nix-store)))
  "Return `project-nix-store-name-prefix' and store path name for PROJECT.

See `project-root' for store path definition."
  (let ((project-root (project-root project)))
    (with-memoization
        (gethash project-root project-nix-store--cached-project-names)
      (concat project-nix-store-name-prefix
              (substring (directory-file-name project-root)
                         (+ (length project-nix-store-dir)
                            ;; length of digest and a hyphen
                            33))))))

;; `project-nix-store-p' is called by `project-remember-project' via `project-list-exclude'.
;; It is possible to call `project-nix-store-p' before the autoloaded `project-nix-store-try'.
;; So autoload it, too.
;;;###autoload
(defun project-nix-store-p (project)
  "Return t if PROJECT is a store project."
  (eq (car-safe project) 'nix-store))

(defun project-nix-store-unload-function ()
  "Do extra cleanup when called by `unload-feature'."
  (defvar unload-feature-special-hooks)
  (cl-flet ((remove-hook-when-needed (hook function)
              (when (and
                     ;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=81550
                     (not (memq hook unload-feature-special-hooks))
                     (boundp hook))
                (remove-hook hook function))))
    (remove-hook-when-needed 'project-find-functions #'project-nix-store-try)
    (remove-hook-when-needed 'project-list-exclude #'project-nix-store-p))
  ;; The standard unloading proceeds.
  nil)

(provide 'project-nix-store)

;;; project-nix-store.el ends here
