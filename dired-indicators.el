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

(defvar dired-indicators-mode-line
  '(:eval dired-indicators--mode-line-text)
  "Mode line construct that displays Dired indicators.")

(defvar-local dired-indicators--mode-line-text nil
  "Current Dired indicator text for the mode line.")

(put 'dired-indicators-mode-line 'risky-local-variable t)

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
       (format " %s%d%s"
               (let ((index (dired-indicators--current-entry-index regexp)))
                 (if index
                     (format "%d/" index)
                   ""))
               count
               suffix)
       'face face))))

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
          (apply #'concat (dired-indicators--segments)))
    (force-mode-line-update)))

(defun dired-indicators--enable ()
  "Enable Dired indicator hooks in the current buffer."
  (add-hook 'post-command-hook #'dired-indicators-update nil 'local)
  (add-hook 'dired-after-readin-hook #'dired-indicators-update nil 'local)
  (dired-indicators-update))

(defun dired-indicators--disable ()
  "Disable Dired indicator hooks in the current buffer."
  (remove-hook 'post-command-hook #'dired-indicators-update 'local)
  (remove-hook 'dired-after-readin-hook #'dired-indicators-update 'local)
  (setq dired-indicators--mode-line-text nil)
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

