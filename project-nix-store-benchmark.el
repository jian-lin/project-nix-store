;;; project-nix-store-benchmark.el --- Benchmark project-nix-store  -*- lexical-binding: t; -*-

;; SPDX-FileCopyrightText: 2026 Lin Jian <me@linj.tech>
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Entry point:
;;   - `project-nix-store-benchmark-run'
;;   - `project-nix-store-benchmark-compare'

;;; Code:

(require 'project-nix-store)
(require 'org)
(require 'org-table)
(require 'json)
(require 'custom)
(eval-when-compile (require 'cl-lib))

;;;; run benchmark and show result

(defvar project-nix-store-benchmark-gc-cons-threshold (* 15 1000 1000)
  "Run benchmarks with `gc-cons-threshold' set to this.
See also `project-nix-store-benchmark-with-interactive-gc'.")
(defvar project-nix-store-benchmark-gc-cons-percentage
  (custom--standard-value 'gc-cons-percentage)
  "Run benchmarks with `gc-cons-percentage' set to this.
See also `project-nix-store-benchmark-with-interactive-gc'.")

(defmacro project-nix-store-benchmark-with-interactive-gc (&rest body)
  "Evaluate BODY with GC configured like in an interactive environment.
See `project-nix-store-benchmark-gc-cons-threshold'
and `project-nix-store-benchmark-gc-cons-percentage'
for the actual config.

Emacs changes `gc-cons-percentage' in batch mode,
but we want to run benchmarks in a normal user environment.

In addition, we manually do GC once before evaluating BODY."
  (declare (indent 0) (debug t))
  `(let ((gc-cons-threshold project-nix-store-benchmark-gc-cons-threshold)
         (gc-cons-percentage project-nix-store-benchmark-gc-cons-percentage))
     (garbage-collect)
     ,@body))

;; We do not store benchmark inputs in variables to not include
;; variable lookup time in benchmark results.

(defun project-nix-store-benchmark--project-nix-store-try ()
  (let ((project-nix-store-dir "/nix/store/")
        (project-nix-store--cached-projects (make-hash-table :test 'equal)))
    (project-nix-store-benchmark-with-interactive-gc
      (benchmark-run-compiled 10000000
        (project-nix-store-try
         "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/site-lisp/elpa/org-9.8.1/")))))

(defun project-nix-store-benchmark--project-nix-store--try-without-cache ()
  (let ((project-nix-store-dir "/nix/store/"))
    (project-nix-store-benchmark-with-interactive-gc
      (benchmark-run-compiled 10000
        (project-nix-store--try-without-cache
         "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/share/emacs/site-lisp/elpa/org-9.8.1/")))))

(defun project-nix-store-benchmark--project-root ()
  (project-nix-store-benchmark-with-interactive-gc
    (benchmark-run-compiled 1000000
      (project-root
       '(nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/")))))

(defun project-nix-store-benchmark--project-name ()
  (let ((project-nix-store-dir "/nix/store/")
        (project-nix-store-name-prefix "/NS/")
        (project-nix-store--cached-project-names (make-hash-table :test 'equal)))
    (project-nix-store-benchmark-with-interactive-gc
      (benchmark-run-compiled 1000000
        (project-name
         '(nix-store . "/nix/store/jnhsnfz13w8ailk2lfs2pvamwa35mxzs-emacs-packages-deps/"))))))

;;;###autoload
(defun project-nix-store-benchmark-run (&optional output-file)
  "Benchmark performance-critical functions of project-nix-store library.

Return a plist in which
each key is the function name being benchmarked
and each value is its benchmark result
in the form of (TIME GC GC-TIME).

When OUTPUT-FILE is a string,
write the json-encoded plist to OUTPUT-FILE.
When OUTPUT-FILE is a symbol `quiet',
do not write nor print anything.
Otherwise, print the json-encoded plist."
  (let* ((result (list "project-nix-store-try"
                       (project-nix-store-benchmark--project-nix-store-try)
                       "project-nix-store--try-without-cache"
                       (project-nix-store-benchmark--project-nix-store--try-without-cache)
                       "project-root"
                       (project-nix-store-benchmark--project-root)
                       "project-name"
                       (project-nix-store-benchmark--project-name)))
         (result-json (json-encode result)))
    (cond
     ((stringp output-file)
      (write-region result-json nil output-file nil nil nil (if noninteractive 'excl t)))
     ((eq output-file 'quiet))
     (t (message "%s" result-json)))
    result))

;;;; compare benchmark results

(defun project-nix-store-benchmark--result-functions (benchmark-result)
  (cl-loop for function in benchmark-result by #'cddr
           collect function))

(defun project-nix-store-benchmark--result-of-function (benchmark-result function)
  (plist-get benchmark-result function #'equal))

(defun project-nix-store-benchmark--diff-results-of-function (result-old result-new)
  (cl-loop for item-old in result-old
           for item-new in result-new
           collect (- item-new item-old)))

(defun project-nix-store-benchmark--result-time-of-function (result)
  (car result))

(defun project-nix-store-benchmark--compare-function-result (result-old result-new)
  (let ((result-diff (project-nix-store-benchmark--diff-results-of-function result-old
                                                                            result-new)))
    (cons (* (/ (project-nix-store-benchmark--result-time-of-function result-diff)
                (project-nix-store-benchmark--result-time-of-function result-old))
             100)
          result-diff)))

(defun project-nix-store-benchmark--compare (result-old result-new)
  (let ((functions-old (project-nix-store-benchmark--result-functions result-old))
        (functions-new (project-nix-store-benchmark--result-functions result-new)))
    (let ((warning-series t))
      (when-let* ((functions-removed (cl-set-difference functions-old functions-new
                                                        :test #'equal)))
        (lwarn 'project-nix-store-benchmark :warning
               "removed functions: %s" functions-removed))
      (when-let* ((functions-added (cl-set-difference functions-new functions-old
                                                      :test #'equal)))
        (lwarn 'project-nix-store-benchmark :warning
               "added functions: %s" functions-added)))
    (cl-loop
     for function in (cl-intersection functions-old functions-new :test #'equal)
     for function-result-old = (project-nix-store-benchmark--result-of-function result-old
                                                                                function)
     for function-result-new = (project-nix-store-benchmark--result-of-function result-new
                                                                                function)
     append (list function
                  (project-nix-store-benchmark--compare-function-result
                   function-result-old
                   function-result-new)))))

(defun project-nix-store-benchmark--render-result-diff-to-org-table (result-diff float-format)
  (with-temp-buffer
    (org-mode)
    ;; content
    (cl-loop for function in (project-nix-store-benchmark--result-functions result-diff)
             for function-result = (project-nix-store-benchmark--result-of-function
                                    result-diff
                                    function)
             do (insert
                 (apply #'format
                        (format "%s,%s,%s,%s,%s\n"
                                "%s"
                                float-format
                                float-format
                                "%d"
                                float-format)
                        (cl-flet ((get-time-percentage (result) (nth 0 result))
                                  (get-time (result) (nth 1 result))
                                  (get-gc (result) (nth 2 result))
                                  (get-gc-time (result) (nth 3 result)))
                          (list function
                                (get-time-percentage function-result)
                                (get-time function-result)
                                (get-gc function-result)
                                (get-gc-time function-result))))))
    ;; to org table
    (org-table-convert-region (point-min) (point-max) '(4))
    ;; add header later to easily add a rule line
    (goto-char (point-min))
    (insert "|function|time %|time|gc|gc-time\n") ; add header
    (insert "|-\n")                               ; add rule line
    (org-table-align)                             ; format and align
    ;; to string
    (buffer-substring-no-properties (point-min) (point-max))))

(defun project-nix-store-benchmark--export-org-table-to-markdown (org-table)
  ;; change the rule line
  (string-replace "+" "|" org-table))

(defun project-nix-store-benchmark--read-result-file (result-file)
  (let ((json-object-type 'plist)
        (json-array-type 'list))
    (json-read-file result-file)))

;;;###autoload
(defun project-nix-store-benchmark-compare
    (result-file-old &optional result-file-new output-file)
  "Compare two benchmark results.

RESULT-FILE-OLD and RESULT-FILE-NEW are benchmark results
produced by `project-nix-store-benchmark-run'.

If RESULT-FILE-NEW is nil,
instead of reading its benchmark result from a file,
we do benchmark by calling `project-nix-store-benchmark-run'
and get result from it.

Return the comparison result, a plist in which
each key is the function symbol bening benchmarked
and each value is the comparison result for that function
in the form of
\(TIME-DIFF-PERCENTAGE TIME-DIFF GC-DIFF GC-TIME-DIFF).

When OUTPUT-FILE is non-nil,
write the comparison result to OUTPUT-FILE.
Otherwise, print the comparison result."
  (let ((result-old (project-nix-store-benchmark--read-result-file result-file-old))
        (result-new (if result-file-new
                        (project-nix-store-benchmark--read-result-file result-file-new)
                      (project-nix-store-benchmark-run 'quiet))))
    (let* ((result-diff (project-nix-store-benchmark--compare result-old result-new))
           (result-diff-org-table (project-nix-store-benchmark--render-result-diff-to-org-table
                                   result-diff
                                   "%.4f"))
           (result-diff-markdown-table (project-nix-store-benchmark--export-org-table-to-markdown
                                        result-diff-org-table)))
      (if output-file
          (write-region result-diff-markdown-table nil output-file t)
        (message "%s" result-diff-org-table))
      result-diff)))

(provide 'project-nix-store-benchmark)

;;; project-nix-store-benchmark.el ends here

;; Local Variables:
;; package-lint-main-file: "project-nix-store.el"
;; checkdoc-force-docstrings-flag: nil
;; End:
