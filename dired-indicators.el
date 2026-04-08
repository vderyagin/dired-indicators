;;; dired-indicators.el --- Dired mode line indicators -*- lexical-binding: t -*-

;; Author: Victor Deryagin <vderyagin@gmail.com>
;; Maintainer: Victor Deryagin <vderyagin@gmail.com>
;; Created: 08 Apr 2026
;; Version: 0.1.0
;; Package-Requires: nil

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This package adds mode line indicators to Dired buffers for marked files
;; and files flagged for deletion. When point is on one of those entries, the
;; indicator also shows the current entry index among the matching items.

;;; Code:

(require 'dired)

(defgroup dired-indicators nil
  "Mode line indicators for Dired marks and deletion flags."
  :group 'dired)

(defcustom dired-indicators-show-marked t
  "Whether to show the marked files indicator in the mode line."
  :type 'boolean
  :group 'dired-indicators)

(defcustom dired-indicators-show-flagged t
  "Whether to show the deletion-flagged files indicator in the mode line."
  :type 'boolean
  :group 'dired-indicators)

(defface dired-indicators-marked-face
  '((t :inherit bold))
  "Face used for the marked files indicator in the mode line."
  :group 'dired-indicators)

(defface dired-indicators-flagged-face
  '((t :inherit bold))
  "Face used for the deletion-flagged files indicator in the mode line."
  :group 'dired-indicators)

(defvar dired-indicators-mode nil)

(defvar-local dired-indicators--mode-line-text nil
  "Current Dired indicator text for the mode line.")

(defconst dired-indicators--mode-line-construct
  '(:eval (dired-indicators--mode-line-string))
  "Mode line construct installed by `dired-indicators-mode'.")

(defvar-local dired-indicators--mode-line-format-was-local nil
  "Whether `mode-line-format' was buffer-local before mode activation.")

(defun dired-indicators--current-entry-index (regexp)
  "Return the 1-based index of the current line matching REGEXP."
  (save-excursion
    (forward-line 0)
    (when (looking-at-p (concat regexp ".*"))
      (1+ (count-matches regexp (point-min) (point))))))

(defun dired-indicators--flagged-regexp ()
  "Return the regexp for Dired deletion flags."
  (let ((dired-marker-char dired-del-marker))
    (dired-marker-regexp)))

(defun dired-indicators--format (regexp suffix face)
  "Return a mode line fragment for REGEXP using SUFFIX and FACE."
  (let ((count (count-matches regexp (point-min) (point-max))))
    (unless (zerop count)
      (propertize
       (format "%s%d%s"
               (let ((index (dired-indicators--current-entry-index regexp)))
                 (if index
                     (format "%d/" index)
                   ""))
               count
               suffix)
       'face face))))

(defun dired-indicators--mode-line-string ()
  "Return the current mode line string for Dired indicators."
  (when dired-indicators--mode-line-text
    (concat dired-indicators--mode-line-text " ")))

(defun dired-indicators--mode-line-format (format)
  "Return FORMAT as a list suitable for editing."
  (if (listp format)
      (copy-tree format)
    (list format)))

(defun dired-indicators--remove-construct (format)
  "Return FORMAT without `dired-indicators--mode-line-construct'."
  (cond
   ((null format) nil)
   ((equal (car format) dired-indicators--mode-line-construct)
    (dired-indicators--remove-construct (cdr format)))
   (t
    (cons (car format)
          (dired-indicators--remove-construct (cdr format))))))

(defun dired-indicators--insert-before-position (format)
  "Insert the Dired indicators construct into FORMAT before `mode-line-position'."
  (cond
   ((null format)
    (list dired-indicators--mode-line-construct))
   ((eq (car format) 'mode-line-position)
    (cons dired-indicators--mode-line-construct format))
   (t
    (cons (car format)
          (dired-indicators--insert-before-position (cdr format))))))

(defun dired-indicators--install-mode-line ()
  "Install the Dired indicators construct into the current buffer mode line."
  (setq dired-indicators--mode-line-format-was-local
        (local-variable-p 'mode-line-format))
  (setq-local mode-line-format
              (thread-last
                mode-line-format
                dired-indicators--mode-line-format
                dired-indicators--remove-construct
                dired-indicators--insert-before-position)))

(defun dired-indicators--uninstall-mode-line ()
  "Remove the Dired indicators construct from the current buffer mode line."
  (let ((format (thread-last
                  mode-line-format
                  dired-indicators--mode-line-format
                  dired-indicators--remove-construct)))
    (if (and (not dired-indicators--mode-line-format-was-local)
             (equal format (default-value 'mode-line-format)))
        (kill-local-variable 'mode-line-format)
      (setq-local mode-line-format format))))

(defun dired-indicators--segments ()
  "Return the enabled indicator segments for the current Dired buffer."
  (delq nil
        (list
         (when dired-indicators-show-marked
           (dired-indicators--format
            (dired-marker-regexp)
            "*"
            'dired-indicators-marked-face))
         (when dired-indicators-show-flagged
           (dired-indicators--format
            (dired-indicators--flagged-regexp)
            "D"
            'dired-indicators-flagged-face)))))

(defun dired-indicators-update ()
  "Update Dired indicator text in the current buffer."
  (when dired-indicators-mode
    (setq dired-indicators--mode-line-text
          (mapconcat #'identity (dired-indicators--segments) " "))
    (force-mode-line-update)))

(defun dired-indicators--enable ()
  "Enable Dired indicator hooks in the current buffer."
  (dired-indicators--install-mode-line)
  (add-hook 'post-command-hook #'dired-indicators-update nil 'local)
  (add-hook 'dired-after-readin-hook #'dired-indicators-update nil 'local)
  (dired-indicators-update))

(defun dired-indicators--disable ()
  "Disable Dired indicator hooks in the current buffer."
  (remove-hook 'post-command-hook #'dired-indicators-update 'local)
  (remove-hook 'dired-after-readin-hook #'dired-indicators-update 'local)
  (setq dired-indicators--mode-line-text nil)
  (dired-indicators--uninstall-mode-line)
  (force-mode-line-update))

;;;###autoload
(define-minor-mode dired-indicators-mode
  "Show mark and deletion indicators in the Dired mode line."
  :lighter nil
  (when (and dired-indicators-mode
             (not (derived-mode-p 'dired-mode)))
    (setq dired-indicators-mode nil)
    (user-error "`dired-indicators-mode' is only supported in Dired buffers"))
  (if dired-indicators-mode
      (dired-indicators--enable)
    (dired-indicators--disable)))

(defun dired-indicators--turn-on ()
  "Enable `dired-indicators-mode' in Dired buffers."
  (when (derived-mode-p 'dired-mode)
    (dired-indicators-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-dired-indicators-mode
  dired-indicators-mode
  dired-indicators--turn-on)

(provide 'dired-indicators)
;;; dired-indicators.el ends here
