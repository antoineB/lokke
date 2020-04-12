;;; Copyright (C) 2015-2019 Rob Browning <rlb@defaultvalue.org>
;;;
;;; This project is free software; you can redistribute it and/or modify
;;; it under the terms of (at your option) either of the following two
;;; licences:
;;;
;;;   1) The GNU Lesser General Public License as published by the Free
;;;      Software Foundation; either version 2.1, or (at your option) any
;;;      later version
;;;
;;;   2) The Eclipse Public License; either version 1.0 or (at your
;;;      option) any later version.

(define-module (lokke collection)
  #:version (0 0 0)
  #:use-module ((ice-9 format) #:select (format))
  #:use-module ((guile) #:hide (peek))
  #:use-module (oop goops)
  #:use-module ((ice-9 match) #:select (match-lambda match-lambda*))
  #:use-module ((srfi srfi-1) #:select (circular-list? proper-list?))
  #:use-module ((srfi srfi-43) #:select (vector-unfold))
  #:use-module ((lokke base syntax) #:select (->> if-let when when-let when-not))
  #:use-module ((lokke base util) #:select (require-nil))
  #:use-module ((lokke base collection)
                #:select (<coll>
                          <lazy-seq>
                          <pair-seq>
                          <seq>
                          <sequential>
                          <vector-seq>
                          apply
                          assoc
                          assoc-in
                          bounded-count
                          coll?
                          concat
                          conj
                          cons
                          const-nth?
                          contains?
                          count
                          counted?
                          dissoc
                          drop
                          empty
                          every?
                          ffirst
                          find
                          first
                          fnext
                          get
                          get-in
                          into
                          keys
                          lazy-seq
                          list?
                          merge
                          next
                          nfirst
                          nnext
                          nth
                          reduce
                          reduce-kv
                          rest
                          second
                          select-keys
                          seq
                          seq->scm-list
                          seq?
                          seqable?
                          sequential?
                          take
                          take-while
                          update
                          update-in
                          vals))
  #:use-module ((lokke base invoke) #:select (invoke))
  #:use-module ((lokke base map) #:select (<map> map?))
  #:use-module ((lokke base map-entry)
                #:select (<map-entry> key map-entry map-entry? val))
  #:use-module ((lokke hash-map) #:select (hash-map))
  #:use-module ((lokke scm vector) #:select (<lokke-vector> lokke-vector))
  #:use-module ((lokke compare) #:select (clj=))
  #:use-module ((lokke compat) #:select (re-export-and-replace!))
  #:use-module ((lokke pr) #:select (pr-on print-on))
  #:export (doall
            dorun
            empty?
            filterv
            iterate
            list*
            mapv
            not-any?
            not-every?
            pop
            range
            repeat
            repeatedly
            some)
  #:re-export (<coll>
               <map>
               <map-entry>
               <seq>
               <sequential>
               assoc-in
               bounded-count
               clj=
               coll?
               concat
               conj
               const-nth?
               contains?
               count
               counted?
               dissoc
               drop
               empty
               every?
               ffirst
               find
               first
               fnext
               get
               get-in
               into
               invoke
               key
               keys
               lazy-seq
               map?
               map-entry
               map-entry?
               next
               nfirst
               nnext
               nth
               pr-on
               print-on
               reduce
               reduce-kv
               rest
               second
               select-keys
               seq
               seq->scm-list
               seq?
               seqable?
               sequential?
               take
               take-while
               update
               update-in
               val
               vals)
  #:replace (peek)
  #:duplicates (merge-generics replace warn-override-core warn last))

(re-export-and-replace! 'apply 'assoc 'cons 'list? 'merge)

(define-method (assoc (x <boolean>) k v)
  (require-nil 'get x)
  (hash-map k v))

(define-method (conj (m <map>) (s <sequential>))
  (unless (= 2 (bounded-count 3 s))
    (scm-error 'wrong-type-arg 'conj
               "sequential collection not length 2 in conj" (list) (list)))
  (assoc m (first s) (second s)))

(define-method (conj (m <map>) (v <vector>))
  (unless (= 2 (vector-length v))
    (scm-error 'wrong-type-arg 'conj
               "Scheme vector not length 2 in conj" (list) (list)))
  (assoc m (vector-ref v 0) (vector-ref v 1)))

(define-method (invoke (key <keyword>) map) (get map key))
(define-method (invoke (key <keyword>) map not-found) (get map key not-found))

(define-method (reversible? x) #f)

;; FIXME: match https://clojure.org/guides/equality#_summary as appropriate

(define-method (clj= (s1 <seq>) (s2 <seq>))
  ;; Could also be implemented via list-compare...
  (if-let [s1 (seq s1)]
    (if-let [s2 (seq s2)]
      (and (clj= (first s1) (first s2))
           (clj= (rest s1) (rest s2)))
      #f)
    (not (seq s2))))


;; FIXME: improper lists, etc.  See DESIGN <pair>s TODO.

;; It looks like on the jvm anything sequential must also be seqable,
;; and so we stick to sequential here so that scheme vectors won't be
;; included, matching the jvm for now.

(define-method (clj= (x <pair>) (y <pair>))
  (and (clj= (car x) (car y))
       (clj= (cdr x) (cdr y))))

(define-method (clj= (s <pair>) x)
  (and (sequential? x) (clj= (seq s) (seq x))))

;; Empty list is <null> in goops
(define-method (clj= (s <null>) x)
  ;; #nil is not sequential? but is seqable?.
  (and (not (eq? #nil x))
       (sequential? x)
       (eq? #nil (seq x))))


(define (show coll emit port open close)
  (display open port)
  (when-let (coll (seq coll))
    (emit (first coll) port)
    (do ((coll (next coll) (next coll)))
        ((nil? coll))
      (display " " port)
      (emit (first coll) port)))
  (display close port))

(define-method (pr-on (s <seq>) port)
  (show s pr-on port "(" ")"))

(define-method (print-on (s <seq>) port)
  (show s print-on port "(" ")"))

;; FIXME: improper lists?

(define-method (pr-on (s <pair>) port)
  (show s pr-on port "(" ")"))

(define-method (print-on (s <pair>) port)
  (show s print-on port "(" ")"))

;; For now, just emulate the same output as Guile, assuming that
;; <class> is always correct.

(define-method (write (s <seq>) port)
  (show s
        (lambda (x port) (write x port))
        port
        (format #f "#<<class> ~s ~x ("
                (class-name (class-of s)) (object-address s))
        ")>"))

(define-method (display (s <seq>) port)
  (show s
        (lambda (x port) (display x port))
        port
        (format #f "#<<class> ~s ~x ("
                (class-name (class-of s)) (object-address s))
        ")>"))

;; FIXME: Implement rseq...
;;
;; (define-method (reversible? (vs <vector-seq>)) #t)

(define (last coll)
  (let ((n (next coll)))
    (if n (last n) (first n))))

(define (butlast coll)
  (let loop ((result '())
             (rst coll))
    (let ((n (next rst)))
      (if n
          (loop (cons (first n) result) (next rst))
          result))))

(define-method (empty? (coll <coll>))
  (if (counted? coll)
      (zero? (count coll))
      (not (seq coll))))

(define-method (empty? (v <vector>))
  (zero? (vector-length v)))

(define-method (empty? (v <list>))
  (null? v))

(define-method (empty? (v <sequential>))
  (eq? #nil (seq v)))

(define-method (empty? (v <null>))
  #t)

(define-method (empty? (v <pair>))
  #f)

(define-method (empty? (b <boolean>))
  (require-nil 'empty? b)
  #t)

(define-method (into to from)
  (reduce conj to from))

;; FIXME: these haven't been tested?

(define dorun
  (match-lambda*
    ((coll) (when-let (s (seq coll))
                      (dorun (next coll))))
    ((n coll) (when (positive? n)
                (when-let (s (seq coll))
                  (dorun (1- n) (next coll)))))))
(define doall
  (match-lambda*
    ((coll) (dorun coll) coll)
    ((n coll) (dorun n coll) coll)))

(define (some f coll)
  (let loop ((rst coll))
    (when-let (s (seq rst))
              (if-let (v (invoke f (first s)))
                      v
                      (loop (rest s))))))

(define repeat
  (match-lambda*
    ((x) (let loop () (lazy-seq (cons x (loop)))))
    ((n x)
     (let loop ((n n))
       (lazy-seq
        (when-not (zero? n)
          (cons x (loop (1- n)))))))))

(define repeatedly
  (match-lambda*
    ((f) (let loop () (lazy-seq (cons (f) (loop)))))
    ((n f)
     (let loop ((n n))
       (lazy-seq
        (when-not (zero? n)
          (cons (f) (loop (1- n)))))))))

(define (iterate f x)
  (cons x (lazy-seq (iterate f (f x)))))

;; FIXME: optimize?
(define range
  (match-lambda*
    (() (iterate 1+ 0))
    ((end) (take end (iterate 1+ 0)))
    ((start end) (take (- end start) (iterate 1+ start)))
    ((start end step)
     (take-while (lambda (x) (< x end))
                 (iterate (lambda [x] (+ x step)) start)))))

(define (not-every? pred coll)
  (not (every? pred coll)))

(define (not-any? pred coll)
  (not (some pred coll)))

(define (mapv f . colls)
  (when (null? colls)
    (scm-error 'wrong-number-of-args
               "mapv"
               "Wrong number of arguments" '() #f))
  (let loop ((result (lokke-vector))
             (nexts colls))
    (if (some nil? nexts)
        result
        (loop (conj result (apply f (map first nexts)))
              (map next nexts)))))

(define (filterv pred coll)
  (let loop ((result (lokke-vector))
             (rst coll))
    (if-let (s (seq rst))
            (let ((x (first s)))
              (loop (if (pred x) (conj result x) result)
                    (rest s)))
            result)))

(define list*
  (case-lambda
    ((s) (seq s))
    ((a s) (cons a (list* s)))
    ((a b s) (cons a (cons b (list* s))))
    ((a b c s) (cons a (cons b (cons c (list* s)))))
    ((a b c d s) (cons a (cons b (cons c (cons d (list* s))))))
    ((a b c d e . more)
     (->> (let loop ((more more))
            (cond
             ((eq? #nil more) #nil)
             ((eq? #nil (next more)) (seq (next more)))
             (else (cons (first more) (loop (next more))))))
          (cons e)
          (cons d)
          (cons c)
          (cons b)
          (cons a)))))


;; The jvm has a persistent stack interface...
;; FIXME: improper lists, etc.  See DESIGN <pair>s TODO.

(define-method (peek (x <boolean>)) (require-nil 'peek x) #nil)
(define-method (peek (x <null>)) #nil)
(define-method (peek (x <pair>)) (car x))

(define-method (pop (x <boolean>)) (require-nil 'pop x) #nil)
(define-method (pop (x <null>)) (error "cannot pop empty list"))
(define-method (pop (x <pair>)) (cdr x))
