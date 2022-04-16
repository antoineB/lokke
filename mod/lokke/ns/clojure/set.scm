;;; Copyright (C) 2021-2022 Rob Browning <rlb@defaultvalue.org>
;;; SPDX-License-Identifier: LGPL-2.1-or-later OR EPL-1.0+

(define-module (lokke ns clojure set)
  #:use-module ((lokke set) #:select (difference intersection union))
  #:use-module ((lokke hash-map) #:select (rename-keys))
  #:use-module ((lokke hash-set) #:select (difference intersection union))
  #:re-export (difference intersection rename-keys union)
  #:duplicates (merge-generics replace warn-override-core warn last))
