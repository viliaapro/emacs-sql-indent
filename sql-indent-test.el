;;; sql-indent-test.el --- Automated tests for sql-indent.el. -*- lexical-binding: t -*-
;; Copyright (C) 2017 Alex Harsanyi
;;
;; Author: Alex Harsanyi (AlexHarsanyi@gmail.com)
;; Created: 23 May 2017
;; Keywords: languages sql
;; Homepage: https://github.com/alex-hhh/emacs-sql-indent
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

;;; Commentary:

;; This file defines tests for the sql-indent.el package.  To run the tests,
;; eval this file, than type:
;;
;;     M-x ert RET "^sqlind-" RET
;;
;; Tests can also be run in batch mode using the following command:
;;
;;    emacs -batch -Q --no-site-file -L . -l sql-indent-test.el -f ert-run-tests-batch-and-exit
;;
;; The above command used '-Q' and '--no-site-file options', making sure that
;; the tests are run in a "standard" environment, regardless of what packages
;; and settings are present in your personal init and site-init files.
;;
;;;; There are two types of tests,
;;
;; * SYNTAX CHECKS check if the syntax in an SQL file is correctly
;;   indentified.  These tests are independent of indentation preferences (see
;;   `sqlind-ert-check-file-syntax')
;;
;; * INDENTATION CHECKS checks if a file is indented corectly for a set of
;;   rules. (see `sqlind-ert-check-file-indentation')
;;
;; Both types of tests work by having a sample SQL file with syntax and
;; indentation data saved in an .eld files.  These data files need to be
;; prepared separately using `sqlind-collect-syntax-from-buffer' and
;; `sqlind-collect-indentation-offsets-from-buffer'.
;;
;;;; Preparing new tests
;;
;; To create a syntax check file, open an *ielm* buffer (M-x ielm RET) and
;; run:
;;
;; (sqlind-collect-syntax-from-buffer (find-file-noselect "./test-data/pr7.sql"))
;;
;; The function will output a set of syntax definitions.  Put these into an
;; .eld file.
;;
;; To create an indentation offsets file, run:
;;
;; (sqlind-collect-indentation-offsets-from-buffer
;;   (find-file-noselect "./test-data/pr7.sql")
;;   sqlind-indentation-left-offsets-alist
;;   2)
;;
;; The function will output a list of indentation offsets.  Put these into an
;; .eld file.
;;
;; See the end of file for examples on how to put together the actual tests.

;;; Code
(require 'ert)
(require 'sql-indent)
(require 'sql-indent-left)


;;................................................ test data preparation ....

(defun sqlind-collect-syntax-from-buffer (buffer)
  (let ((result '()))
    (with-current-buffer buffer
      ;; NOTE: we indent the buffer according to the default rules first, as
      ;; this affects anchor points.  We could get rid of this if we write a
      ;; smarter `sqlind-ert-check-line-syntax'
      (sqlind-ert-indent-buffer
       (default-value 'sqlind-indentation-offsets-alist)
       (default-value 'sqlind-basic-offset))
      (goto-char (point-min))
      (let ((syn (sqlind-syntax-of-line)))
        (setq result (cons syn result)))
      (while (= (forward-line 1) 0)
        (let ((syn (sqlind-syntax-of-line)))
          (setq result (cons syn result)))))
    (reverse result)))

(defun sqlind-collect-indentation-offsets-from-buffer (buffer rules basic-offset)
  (let ((result '()))
    (with-current-buffer buffer
      (sqlind-ert-indent-buffer
       (or rules (default-value 'sqlind-indentation-offsets-alist))
       (or basic-offset (default-value 'sqlind-basic-offset)))
      (goto-char (point-min))
      (setq result (cons (current-indentation) result))
      (while (= (forward-line 1) 0)
        (setq result (cons (current-indentation) result))))
    (reverse result)))


;;......................................................... test helpers ....

(defun sqlind-ert-indent-buffer (rules basic-offset)
  "Indent the buffer according to RULES and BASIC-OFFSET.
The RULES and BASIC-OFFSET are installed as
`sqlind-indentation-offsets-alist' and `sqlind-basic-offset' than
inddent the whole buffer."
  (when rules
    (setq sqlind-indentation-offsets-alist rules))
  (when basic-offset
    (setq sqlind-basic-offset basic-offset))
  ;; To ensure we are consistent in our offsets regardless of he users
  ;; personal tab choices, setup spaces only indentation for this buffer.
  (setq indent-tabs-mode nil)
  (untabify (point-min) (point-max))
  (indent-region (point-min) (point-max))
  ;; (save-buffer) ; if you want to see the result of this command
  (set-buffer-modified-p nil))

(defun sqlind-ert-check-line-syntax (expected)
  "Check that the current line has EXPECTED syntax.
Get the syntax of the current line in the current buffer using
`sqlind-syntax-of-line' and compare it against EXPECTED. 

 The comparison is done using the `should' ERT macro, so this
function should be run a part of an ERT test."
  (let ((actual (sqlind-syntax-of-line))
        (info (format "%s:%s"
                      (buffer-file-name)
                      (line-number-at-pos))))
    ;; NOTE: should does not appear to have a message argument, so the "cons"
    ;; trick is used to add some information in case of failure.
    (should
     (equal (cons info actual) (cons info expected)))))

(defun sqlind-ert-read-data (file)
  "Read saved ELISP data from FILE."
  (with-current-buffer (or (get-buffer file)
                           (find-file-noselect file))
    (goto-char (point-min))
    (read (current-buffer))))

(defun sqlind-ert-check-file-syntax (sql-file data-file)
  "Check the syntax of each line in SQL-FILE.
The syntax of each line in SQL-FILE is checked against the
previously saved syntax data in DATA-FILE.  An error is signaled
if there is a mismatch."
  (let ((syntax-data (sqlind-ert-read-data data-file)))
    (with-current-buffer (find-file sql-file)
      (sqlind-minor-mode 1)             ; ensure this is enabled
      ;; NOTE: indent the buffer according to default rules first -- this
      ;; affects anchor points.
      ;; (message "sql-product: %s" sql-product)
      (sqlind-ert-indent-buffer
       (default-value 'sqlind-indentation-offsets-alist)
       (default-value 'sqlind-basic-offset))
      (goto-char (point-min))
      (should (consp syntax-data))    ; "premature end of syntax-data"
      (sqlind-ert-check-line-syntax (car syntax-data))
      (setq syntax-data (cdr syntax-data))
      (while (= (forward-line 1) 0)
        (should (consp syntax-data))  ; "premature end of syntax-data"
        (sqlind-ert-check-line-syntax (car syntax-data))
        (setq syntax-data (cdr syntax-data))))))

(defun sqlind-ert-check-line-indentation (expected)
  "Check that the current line has EXPECTED indentation.
The comparison is done using the `should' ERT macro, so this
function should be run a part of an ERT test."
  (let ((actual (current-indentation))
        (info (format "%s:%s"
                      (buffer-file-name)
                      (line-number-at-pos))))
    ;; NOTE: should does not appear to have a message argument, so the "cons"
    ;; trick is used to add some information in case of failure.
    (should
     (equal (cons info actual) (cons info expected)))))

(defun sqlind-ert-check-file-indentation (sql-file data-file rules basic-offset)
  "Check that SQL-FILE is indented correctly according to RULES
and BASIC-OFFSET The file is indented first according to RULES
and BASIC-OFFSET, than each line is compared with the indentation
information read from DATA-FILE (as generated by
`sqlind-collect-indentation-offsets-from-buffer')"
  (let ((indentation-data (sqlind-ert-read-data data-file)))
    (with-current-buffer (find-file sql-file)
      (sqlind-minor-mode 1)
      ;; (message "sql-product: %s" sql-product)
      (sqlind-ert-indent-buffer rules basic-offset)
      (goto-char (point-min))
      (should (consp indentation-data))    ; "premature end of indentation-data
      (sqlind-ert-check-line-indentation (car indentation-data))
      (setq indentation-data (cdr indentation-data))
      (while (= (forward-line 1) 0)
        (should (consp indentation-data))  ; "premature end of syntax-data"
        (sqlind-ert-check-line-indentation (car indentation-data))
        (setq indentation-data (cdr indentation-data))))))


;;..................................................... the actual tests ....

;; See https://gist.github.com/alex-hhh/834a91621680e826a27b2b08463eb12f

(defvar m-indentation-offsets-alist
  `((select-clause                 0)
    (insert-clause                 0)
    (delete-clause                 0)
    (update-clause                 0)
    (in-insert-clause              +)
    (in-select-clause              sqlind-lineup-to-clause-end
                                   sqlind-lineup-close-paren-to-open)
    (nested-statement-continuation sqlind-lineup-into-nested-statement
                                   sqlind-align-comma
                                   sqlind-lineup-close-paren-to-open)
    (select-column                 sqlind-indent-select-column
                                   sqlind-align-comma)
    (select-column-continuation    sqlind-indent-select-column
                                   sqlind-lineup-close-paren-to-open)
    (select-table-continuation     sqlind-indent-select-table
                                   sqlind-lineup-joins-to-anchor
                                   sqlind-lineup-open-paren-to-anchor
                                   sqlind-lineup-close-paren-to-open
                                   sqlind-align-comma)
    ,@sqlind-default-indentation-offsets-alist))

(ert-deftest sqlind-ert-pr17 ()
  (sqlind-ert-check-file-syntax "test-data/pr17.sql" "test-data/pr17-syn.eld"))

(ert-deftest sqlind-ert-pr17-indentation-default ()
  (sqlind-ert-check-file-indentation
   "test-data/pr17.sql" "test-data/pr17-io-default.eld"
   (default-value 'sqlind-indentation-offsets-alist)
   (default-value 'sqlind-basic-offset)))

(ert-deftest sqlind-ert-pr17-indentation-left ()
  (sqlind-ert-check-file-indentation
   "test-data/pr17.sql" "test-data/pr17-io-left.eld"
   sqlind-indentation-left-offsets-alist
   (default-value 'sqlind-basic-offset)))

(ert-deftest sqlind-ert-pr17-indentation-right ()
  (sqlind-ert-check-file-indentation
   "test-data/pr17.sql" "test-data/pr17-io-right.eld"
   sqlind-indentation-right-offsets-alist
   (default-value 'sqlind-basic-offset)))

(ert-deftest sqlind-ert-pr7 ()
  (sqlind-ert-check-file-syntax "test-data/pr7.sql" "test-data/pr7-syn.eld"))

(ert-deftest sqlind-ert-case-stmt ()
  (sqlind-ert-check-file-syntax "test-data/case-stmt.sql" "test-data/case-stmt-syn.eld"))

(ert-deftest sqlind-ert-m-syn ()
  (sqlind-ert-check-file-syntax "test-data/m.sql" "test-data/m-syn.eld"))

(ert-deftest sqlind-ert-m-io ()
  (sqlind-ert-check-file-indentation
   "test-data/m.sql" "test-data/m-io.eld"
   m-indentation-offsets-alist 4))

(ert-deftest sqlind-ert-pr18 ()
  (sqlind-ert-check-file-syntax "test-data/pr18.sql" "test-data/pr18-syn.eld"))

(ert-deftest sqlind-ert-pr19 ()
  (sqlind-ert-check-file-syntax "test-data/pr19.sql" "test-data/pr19-syn.eld"))

;;; sql-indent-test.el ends here
