;;; -*- lexical-binding: t -*-

(require 'ert)
(require 'dired)
(require 'dired-indicators)

(defmacro dired-indicators-test-with-dired-buffer (files &rest body)
  (declare (indent 1))
  `(let (buffer temp-dir)
     (unwind-protect
         (progn
           (setq temp-dir (make-temp-file "dired-indicators-test" t))
           (mapc
            (lambda (file)
              (write-region "" nil (expand-file-name file temp-dir) nil 'silent))
            ,files)
           (setq buffer (dired-noselect temp-dir))
           (with-current-buffer buffer
             ,@body))
       (when (buffer-live-p buffer)
         (kill-buffer buffer))
       (when temp-dir
         (delete-directory temp-dir t)))))

(defun dired-indicators-test-goto-file (file)
  "Move point to FILE in the current Dired buffer."
  (dired-goto-file (expand-file-name file default-directory)))

(defun dired-indicators-test-mark-file (file)
  "Mark FILE in the current Dired buffer."
  (dired-indicators-test-goto-file file)
  (dired-mark 1))

(defun dired-indicators-test-flag-file (file)
  "Flag FILE for deletion in the current Dired buffer."
  (dired-indicators-test-goto-file file)
  (dired-flag-file-deletion 1))

(provide 'test/test-helper)

