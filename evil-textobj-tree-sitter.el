;;; evil-textobj-tree-sitter.el --- Provides evil textobjects using tree-sitter -*- lexical-binding: t; -*-

;; URL: https://github.com/meain/evil-textobj-tree-sitter
;; Keywords: evil, tree-sitter, text-object, convenience
;; SPDX-License-Identifier: Apache-2.0
;; Package-Requires: ((emacs "25.1") (evil "1.0.0") (tree-sitter "0.15.0"))
;; Version: 0.1

;;; Commentary:
;; This package is a port of nvim-treesitter/nvim-treesitter-textobjects.
;; This package will let you create evil textobjects using the power
;; of tree-sitter grammars.  You can easily create
;; function,class,comment etc textobjects in multiple languages.
;;
;; You can do a sample map like below to create a function textobj.
;; (define-key evil-outer-text-objects-map "f"
;;             (evil-textobj-tree-sitter-get-textobj "function.outer"))
;; `evil-textobj-tree-sitter-get-textobj' will return you a function
;; that you can use in a define-key map.  You can pass in any of the
;; supported queries as an arg of that function.  You can also pass in
;; multiple queries as a list and we will match on all of them, ranked
;; on which ones comes up first in the file.
;; You can find more info in the  README.md file at
;; https://github.com/meain/evil-textobj-tree-sitter

;;; Code:

(require 'cl-lib)
(require 'evil)
(require 'tree-sitter)

(defgroup evil-textobj-tree-sitter nil "Text objects based on tree-sitter for Evil"
  :group 'evil)

(defconst evil-textobj-tree-sitter--dir (file-name-directory (locate-library "evil-textobj-tree-sitter.el"))
  "The directory where the library `tree-sitter-langs' is located.")

(defconst evil-textobj-tree-sitter--queries-dir (file-name-as-directory (concat evil-textobj-tree-sitter--dir "queries")))

(defcustom evil-textobj-tree-sitter-major-mode-language-alist nil
  "Alist that maps major modes to tree-sitter language names."
  :group 'evil-textobj-tree-sitter
  :type '(alist :key-type symbol
                :value-type string))
(pcase-dolist (`(,major-mode . ,lang-symbol)
               (reverse '((sh-mode . "bash")
                          (shell-script-mode . "bash")
                          (c-mode . "c")
                          (csharp-mode . "csharp")
                          (c++-mode . "cpp")
                          (go-mode . "go")
                          (html-mode . "html")
                          (java-mode . "java")
                          (javascript-mode . "javascript")
                          (js-mode . "javascript")
                          (js2-mode . "javascript")
                          (js3-mode . "javascript")
                          (julia-mode . "julia")
                          (php-mode . "php")
                          (python-mode . "python")
                          (rjsx-mode . "javascript")
                          (ruby-mode . "ruby")
                          (rust-mode . "rust")
                          (rustic-mode . "rust")
                          (typescript-mode . "typescript"))))
  (setf (map-elt evil-textobj-tree-sitter-major-mode-language-alist
                 major-mode) lang-symbol))

(defun evil-textobj-tree-sitter--nodes-within (nodes)
  "NODES which contain the current point inside them ordered inside out."
  (sort (cl-remove-if-not (lambda (x)
                            (and (<= (car (tsc-node-byte-range x)) (point))
                                 (< (point) (cdr (tsc-node-byte-range x)))))
                          nodes)
        (lambda (x y)
          (< (+ (abs (- (point)
                        (car (tsc-node-byte-range x))))
                (abs (- (point)
                        (cdr (tsc-node-byte-range x))))) (+ (abs (- (point)
                        (car (tsc-node-byte-range y))))
                (abs (- (point)
                        (cdr (tsc-node-byte-range y)))))))))

(defun evil-textobj-tree-sitter--nodes-after (nodes)
  "NODES which contain the current point before them ordered top to bottom."
  (cl-remove-if-not (lambda (x)
                      (> (car (tsc-node-byte-range x)) (point)))
                    nodes))

(defun evil-textobj-tree-sitter--get-nodes (group count)
  "Get a list of viable nodes based on GROUP value.
They will be order with captures with point inside them first then the
ones that follow.  This will return n(COUNT) items."
  ;; TODO: handle missing language queries gracefully
  (let* ((lang-file (alist-get major-mode evil-textobj-tree-sitter-major-mode-language-alist))
         (query-filename (concat evil-textobj-tree-sitter--queries-dir
                                 lang-file "/textobjects.scm"))
         (debugging-query (with-temp-buffer
                            (insert-file-contents query-filename)
                            (buffer-string)))
         (root-node (tsc-root-node tree-sitter-tree))
         (query (tsc-make-query tree-sitter-language debugging-query))
         (captures (tsc-query-captures query root-node #'tsc--buffer-substring-no-properties))
         (filtered-captures (cl-remove-if-not (lambda (x)
                                                (member (car x) group))
                                              captures))
         (nodes (seq-map #'cdr filtered-captures))
         (nodes-nodupes (cl-remove-duplicates nodes
                                              :test (lambda (x y)
                                                      (and (= (car (tsc-node-byte-range x)) (car (tsc-node-byte-range y)))
                                                           (= (cdr (tsc-node-byte-range x)) (cdr (tsc-node-byte-range y)))))))
         (nodes-within (evil-textobj-tree-sitter--nodes-within nodes-nodupes))
         (nodes-after (evil-textobj-tree-sitter--nodes-after nodes-nodupes)))
    (cl-subseq (append nodes-within nodes-after)
               0
               count)))

(defun evil-textobj-tree-sitter--range (count ts-group)
  "Get the range of the closest item of type `TS-GROUP'.
`COUNT' is supported even thought it does not actually make sense in
most cases as if we do 3-in-func the selections will not be continues,
but we can only provide the start and end as of now which is what we
are doing.  `TYPE' can probably be used to append inner or outer."
  (if (equal tree-sitter-mode nil)
      (message "tree-sitter-mode not enabled for buffer")
    (let* ((nodes (evil-textobj-tree-sitter--get-nodes ts-group
                                                       count))
           (range-min (apply #'min
                             (seq-map (lambda (x)
                                        (car (tsc-node-byte-range x)))
                                      nodes)))
           (range-max (apply #'max
                             (seq-map (lambda (x)
                                        (cdr (tsc-node-byte-range x)))
                                      nodes))))
      ;; Have to compute min and max like this as we might have nested functions
      ;; We have to use `cl-callf byte-to-position` ot the positioning might be off for unicode chars
      (cons (cl-callf byte-to-position range-min) (cl-callf byte-to-position range-max)))))

;;;###autoload
(defmacro evil-textobj-tree-sitter-get-textobj (group)
  "Macro to create a textobj function from `GROUP'.
You can pass in multiple groups as a list and in that case as long as
any one of them is valid, it will be picked.  Check this url for
available objects https://github.com/nvim-treesitter/nvim-treesitter-textobjects#built-in-textobjects"
  (declare (debug t) (indent defun))
  (let* ((groups (if (eq (type-of group) 'string)
                     (list group)
                   group))
         (funsymbol (intern (concat "evil-textobj-tree-sitter-function--"
                                    (mapconcat 'identity groups "-"))))
         (interned-groups (mapcar #'intern groups)))
    `(evil-define-text-object ,funsymbol
       (count &rest _)
       (let ((range (evil-textobj-tree-sitter--range count ',interned-groups)))
         (evil-range (car range)
                     (cdr range))))))

;;;###autoload
(defmacro evil-textobj-treesitter-get-textobj (group)
  "Util to help with name transition.
We are changing from evil-textobj-treesitter to evil-textobj-tree-sitter.
`GROUP' is just passed on directly to the actual function."
  (declare (debug t) (indent defun))
  (let* ((groups (if (eq (type-of group) 'string)
                     (list group)
                   group))
         (funsymbol (intern (concat "evil-textobj-tree-sitter-function--"
                                    (mapconcat 'identity groups "-"))))
         (interned-groups (mapcar #'intern groups)))
    (progn
      (message "[DEPRECATED] Use evil-texobj-tree-sitter-get-textobj instead of evil-textojb-treesittter-get-textobj")
      `(evil-define-text-object ,funsymbol
         (count &rest _)
         (let ((range (evil-textobj-tree-sitter--range count ',interned-groups)))
           (evil-range (car range)
                       (cdr range)))))))

(provide 'evil-textobj-tree-sitter)
;;; evil-textobj-tree-sitter.el ends here