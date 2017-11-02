#lang racket/base

;; A simple implementation of the binary decision diagram (BDD)
;; representation of DNF set-theoretic types from
;; "Covariance and Contravariance: a fresh look at an old issue",
;; section 4.

(require racket/match
         (only-in racket/unsafe/ops unsafe-fx<)
         "subtype-test-suite.rkt")

(provide (all-defined-out))


;
;
;
;   ;;;;;;;
;      ;
;      ;
;      ;     ;     ;  ; ;;;      ;;;
;      ;      ;   ;;  ;;   ;    ;   ;
;      ;      ;   ;   ;     ;  ;     ;
;      ;      ;   ;   ;     ;  ;     ;
;      ;       ; ;;   ;     ;  ;;;;;;;
;      ;       ; ;    ;     ;  ;
;      ;        ;;    ;;   ;    ;    ;
;      ;        ;;    ; ;;;      ;;;;
;               ;     ;
;               ;     ;
;             ;;      ;
;



; base   : Base
; prods  : BDD of Prod
; arrows : BDD of Arrow
(struct Type (base prods arrows) #:transparent)


(define (Type<? t1 t2)
  (match* (t1 t2)
    [((Type base1 prods1 arrows1)
      (Type base2 prods2 arrows2))
     (cond
       [(Base<? base1 base2) #t]
       [(Base<? base2 base1) #f]
       [(BDD<? prods1 prods2) #t]
       [(BDD<? prods2 prods1) #f]
       [(BDD<? arrows1 arrows2) #t]
       [else #f])]))


; Type Type -> Type
(define (And t1 t2)
  (match* (t1 t2)
    [((Type base1 prods1 arrows1)
      (Type base2 prods2 arrows2))
     (Type (-base-and base1 base2)
           (-and prods1  prods2)
           (-and arrows1 arrows2))]))

; Type ... -> Type
(define (And* ts)
  (foldl And Univ ts))

; Type Type -> Type
(define (Or t1 t2)
  (match* (t1 t2)
    [((Type base1 prods1 arrows1)
      (Type base2 prods2 arrows2))
     (Type (-base-or base1 base2)
           (-or prods1  prods2)
           (-or arrows1 arrows2))]))

; Type ... -> Type
(define (Or* ts)
  (foldl Or Empty ts))

; Type Type -> Type
(define (Diff t1 t2)
  (match* (t1 t2)
    [((Type base1 prods1 arrows1)
      (Type base2 prods2 arrows2))
     (Type (-base-diff base1 base2)
           (-diff prods1 prods2)
           (-diff arrows1 arrows2))]))

; Type -> Type
(define (Not t)
  (Diff Univ t))




(define top 'Top)
(define bot 'Bot)

(define (Top? x) (eq? x 'Top))
(define (Bot? x) (eq? x 'Bot))



;
;
;
;   ;;;;;;
;   ;    ;;
;   ;     ;
;   ;     ;    ;;;;    ;;;;;     ;;;
;   ;    ;;   ;    ;  ;     ;   ;   ;
;   ;;;;;          ;  ;        ;     ;
;   ;    ;;   ;;;;;;  ;;;;     ;     ;
;   ;     ;  ;;    ;     ;;;;  ;;;;;;;
;   ;     ;  ;     ;        ;  ;
;   ;    ;;  ;    ;;  ;     ;   ;    ;
;   ;;;;;;    ;;;; ;   ;;;;;     ;;;;
;
;
;
;

; (-> (Listof Integer)
;     (Listof Integer)
;     (Listof Integer))
(define (list-or xs ys)
  (match* (xs ys)
    [((list) _) ys]
    [(_ (list)) xs]
    [((cons x xs-rst) (cons y ys-rst))
     (cond
       [(< x y)
        (cons x (list-or xs-rst ys))]
       [(= x y)
        (list-or xs-rst ys)]
       [else (cons y (list-or ys-rst xs))])]))

; (-> (Listof Integer)
;     (Listof Integer)
;     (Listof Integer))
(define (list-and xs ys)
  (match* (xs ys)
    [((list) _) '()]
    [(_ (list)) '()]
    [((cons x xs-rst) (cons y ys-rst))
     (cond
       [(< x y) (list-and xs-rst ys)]
       [(= x y) (cons x (list-and xs-rst ys-rst))]
       [else (list-and ys-rst xs)])]))

; (-> (Listof Integer)
;     (Listof Integer)
;     (Listof Integer))
(define (list-diff xs ys)
  (remv* ys xs))

; (-> (Listof Integer)
;     (Listof Integer)
;     Boolean)
(define (list<? xs ys)
  (match* (xs ys)
    [((cons x xs-rst)
      (cons y ys-rst))
     (cond
       [(< x y) #t]
       [(= x y) (list<? xs-rst ys-rst)]
       [else #f])]
    [(_ (? pair?)) #t]
    [(_ _) #f]))


; interpretation:
; DNF for base types can always be simplified
;; and represented as the following forms
;  (or b₁ b₂ ...) -- i.e. one of
; bits : (Listof Int)
(struct BasePos (bits) #:transparent)
; or
; ¬(or b₁ b₂ ...)) -- i.e. none of
; bits : (Listof Int)
(struct BaseNeg (bits) #:transparent)

; Base is BasePos or BaseNeg

(define -base-pos BasePos)
(define -base-neg BaseNeg)

(define (-base-type b)
  (Type (-base-pos b) bot bot))

(define (Base<? b1 b2)
  (match* (b1 b2)
    [((BasePos _) (BaseNeg _)) #t]
    [((BaseNeg _) (BasePos _)) #f]
    [((BasePos bits1)
      (BasePos bits2))
     (list<? bits1 bits2)]
    [((BaseNeg bits1)
      (BaseNeg bits2))
     (list<? bits1 bits2)]))

(define top-base (-base-neg '()))

(define (Top-base? b)
  (equal? b top-base))


(define bot-base (-base-pos '()))

(define (Bot-base? b)
  (equal? b bot-base))


(define Unit (-base-type (list 0)))
(define Str (-base-type (list 1)))
(define T (-base-type (list 2)))
(define F (-base-type (list 3)))
(define NegInt<Int32-bits (list 4))
(define Int32<Int16-bits (list 5))
(define Int16<Int8-bits (list 6))
(define Int8<Zero-bits (list 7))
(define Zero-bits (list 8))
(define Int8>Zero-bits (list 9))
(define UInt8>Int8-bits (list 10))
(define Int16>UInt8-bits (list 11))
(define UInt16>Int16-bits (list 12))
(define Int32>UInt16-bits (list 13))
(define UInt32>Int32-bits (list 14))
(define PosInt>UInt32-bits (list 15))

(define UInt8
  (-base-type (sort (append Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits)
                    <)))
(define Int8
  (-base-type (sort (append Int8<Zero-bits
                            Zero-bits
                            Int8>Zero-bits)
                    <)))
(define UInt16
  (-base-type (sort (append Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits
                            UInt16>Int16-bits)
                    <)))
(define Int16
  (-base-type (sort (append Int16<Int8-bits
                            Int8<Zero-bits
                            Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits)
                    <)))
(define UInt32
  (-base-type (append Zero-bits
                      Int8>Zero-bits
                      UInt8>Int8-bits
                      Int16>UInt8-bits
                      UInt16>Int16-bits
                      Int32>UInt16-bits
                      UInt32>Int32-bits)))
(define Int32
  (-base-type (sort (append Int32<Int16-bits
                            Int16<Int8-bits
                            Int8<Zero-bits
                            Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits
                            UInt16>Int16-bits
                            Int32>UInt16-bits
                            UInt32>Int32-bits)
                    <)))

(define PosInt
  (-base-type (sort (append Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits
                            UInt16>Int16-bits
                            Int32>UInt16-bits
                            PosInt>UInt32-bits)
                    <)))

(define Nat
  (-base-type (sort (append Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits
                            UInt16>Int16-bits
                            Int32>UInt16-bits
                            PosInt>UInt32-bits)
                    <)))

(define NegInt
  (-base-type (sort (append NegInt<Int32-bits
                            Int32<Int16-bits
                            Int16<Int8-bits
                            Int8<Zero-bits)
                    <)))

(define Int
  (-base-type (sort (append NegInt<Int32-bits
                            Int32<Int16-bits
                            Int16<Int8-bits
                            Int8<Zero-bits
                            Zero-bits
                            Int8>Zero-bits
                            UInt8>Int8-bits
                            Int16>UInt8-bits
                            UInt16>Int16-bits
                            Int32>UInt16-bits
                            PosInt>UInt32-bits)
                    <)))


; (-> Base Base Base)
(define (-base-or b1 b2)
  (match* (b1 b2)
    [((BasePos pos1) (BasePos pos2))
     (-base-pos (list-or pos1 pos2))]
    [((BaseNeg neg1) (BaseNeg neg2))
     (-base-neg (list-and neg1 neg2))]
    [((BasePos pos) (BaseNeg neg))
     (-base-neg (list-diff neg pos))]
    [((BaseNeg neg) (BasePos pos))
     (-base-neg (list-diff neg pos))]))

; (-> Base Base Base)
(define (-base-and t1 t2)
  (match* (t1 t2)
    [((BasePos pos1) (BasePos pos2))
     (-base-pos (list-and pos1 pos2))]
    [((BaseNeg neg1) (BaseNeg neg2))
     (-base-neg (list-or neg1 neg2))]
    [((BasePos pos) (BaseNeg neg))
     (-base-pos (list-diff pos neg))]
    [((BaseNeg neg) (BasePos pos))
     (-base-pos (list-diff pos neg))]))


; (-> Base Base Base)
(define (-base-diff b1 b2)
  (match* (b1 b2)
    [((BasePos pos1) (BasePos pos2))
     (-base-pos (list-diff pos1 pos2))]
    [((BaseNeg neg1) (BaseNeg neg2))
     (-base-pos (list-diff neg2 neg1))]
    [((BasePos pos) (BaseNeg neg))
     (-base-pos (list-and pos neg))]
    [((BaseNeg neg) (BasePos pos))
     (-base-neg (list-or pos neg))]))

; (-> Base Base)
(define (-base-not b)
  (match b
    [(BasePos bits) (-base-neg bits)]
    [(BaseNeg bits) (-base-pos bits)]))




;
;
;
;   ;;;;;;   ;;;;;    ;;;;;
;   ;    ;;  ;   ;;   ;   ;;
;   ;     ;  ;    ;   ;    ;
;   ;     ;  ;     ;  ;     ;
;   ;    ;;  ;     ;  ;     ;
;   ;;;;;    ;     ;  ;     ;
;   ;    ;;  ;     ;  ;     ;
;   ;     ;  ;     ;  ;     ;
;   ;     ;  ;    ;   ;    ;
;   ;    ;;  ;   ;;   ;   ;;
;   ;;;;;;   ;;;;;    ;;;;;
;
;
;
;


(struct Prod (l r) #:transparent)

(struct Arrow (dom rng) #:transparent)

; interp: (Node p l u r) == if p then (l or u) else (r or u)
(struct Node (a l u r) #:transparent)

; a BDD is Top, Bot, or a Node

(define (Atom<? a1 a2)
  (match* (a1 a2)
    [((Prod t1 t2)
      (Prod s1 s2))
     (cond
       [(Type<? t1 s1) #t]
       [(Type<? s1 t1) #f]
       [(Type<? t2 s2) #t]
       [else #f])]
    [((Arrow t1 t2)
      (Arrow s1 s2))
     (cond
       [(Type<? t1 s1) #t]
       [(Type<? s1 t1) #f]
       [(Type<? t2 s2) #t]
       [else #f])]
    [((? Prod?) (? Arrow?)) #t]
    [(_ _) #f]))


(define (-node a l u r)
  (cond
    [(Top? u) top]
    [(equal? l r) (-or l u)]
    [else (Node a l u r)]))



(define (-prod-type l r)
  (Type bot-base (-node (Prod l r) top bot bot) bot))


(define (-arrow-type l r)
  (Type bot-base bot (-node (Arrow l r) top bot bot)))


(define (BDD<? b1 b2)
  (match b1
    ;; Top precedes Bot and Node
    [(? Top?) (not (Top? b2))]
    ;; Bot precedes Node
    [(? Bot?) (Node? b2)]
    [(Node p1 _ _ _)
     (match b2
       [(Node p2 _ _ _)
        (cond
          [(Atom<? p1 p2) #t]
          [(Atom<? p2 p1) #f]
          [(BDD<? (Node-l b1)
                  (Node-l b2))
           #t]
          [(BDD<? (Node-l b2)
                  (Node-l b1))
           #f]
          [(BDD<? (Node-u b1)
                  (Node-u b2))
           #t]
          [(BDD<? (Node-u b2)
                  (Node-u b1))
           #f]
          [(BDD<? (Node-r b1)
                  (Node-r b2))
           #t]
          [else #f])]
       [_ #f])]))


(define (-or b1 b2)
  (match* (b1 b2)
    [(b b) b]
    [((? Top?) _) top]
    [(_ (? Top?)) top]
    [((? Bot?) b) b]
    [(b (? Bot?)) b]
    [((Node p1 _ _ _)
      (Node p2 _ _ _))
     (cond
       [(Atom<? p1 p2)
        (match-define (Node _ l1 u1 r1) b1)
        (-node p1 l1 (-or u1 b2) r1)]
       [(Atom<? p2 p1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p2 l2 (-or b1 u2) r2)]
       [else
        (match-define (Node _ l1 u1 r1) b1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p1
               (-or l1 l2)
               (-or u1 u2)
               (-or r1 r2))])]))



(define (-and b1 b2)
  (match* (b1 b2)
    [(b b) b]
    [((? Top?) b) b]
    [(b (? Top?)) b]
    [((? Bot?) _) bot]
    [(_ (? Bot?)) bot]
    [((Node p1 _ _ _)
      (Node p2 _ _ _))
     (cond
       [(Atom<? p1 p2)
        (match-define (Node _ l1 u1 r1) b1)
        (-node p1
               (-and l1 b2)
               (-and u1 b2)
               (-and r1 b2))]
       [(Atom<? p2 p1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p2
               (-and b1 l2)
               (-and b1 u2)
               (-and b1 r2))]
       [else
        (match-define (Node _ l1 u1 r1) b1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p1
               (-and (-or l1 u1)
                     (-or l2 u2))
               bot
               (-and (-or r1 u1)
                     (-or r2 u2)))])]))


(define (-neg b)
  (match b
    [(? Top?) bot]
    [(? Bot?) top]
    [(Node p l u (? Bot?))
     (-node p
            bot
            (-neg (-or u l))
            (-neg u))]
    [(Node p (? Bot?) u r)
     (-node p
            (-neg u)
            (-neg (-or u r))
            bot)]
    [(Node p l (? Bot?) r)
     (-node p
            (-neg l)
            (-neg (-or l r))
            (-neg l))]
    [(Node p l u r)
     (-node p
            (-neg (-or l u))
            bot
            (-neg (-or r u)))]))


(define (-diff b1 b2)
  (match* (b1 b2)
    [(b b) bot]
    [(_ (? Top?)) bot]
    [((? Bot?) _) bot]
    [(b (? Bot?)) b]
    [((? Top?) _) (-neg b2)]
    [((Node p1 _ _ _)
      (Node p2 _ _ _))
     (cond
       [(Atom<? p1 p2)
        ;; NOTE: different from paper, consistent w/ CDuce
        (match-define (Node _ l1 u1 r1) b1)
        (-node p1
               (-diff l1 b2)
               (-diff u1 b2)
               (-diff r1 b2))]
       [(Atom<? p2 p1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p2
               (-diff b1 (-or l2 u2))
               bot
               (-diff b1 (-or r2 u2)))]
       [else
        (match-define (Node _ l1 u1 r1) b1)
        (match-define (Node _ l2 u2 r2) b2)
        (-node p1
               (-diff l1 l2)
               (-diff u1 u2)
               (-diff r1 r2))])]))




(define Univ (Type top-base top top))
(define Empty (Type bot-base bot bot))


(define (->Type sexp)
  (match sexp
    ['Univ Univ]
    ['Empty Empty]
    ['Unit Unit]
    ['Bool (Or T F)]
    ['Str Str]
    ['UnivProd (-prod-type Univ Univ)]
    ['UnivArrow (-arrow-type Empty Univ)]
    ['Int Int]
    ['T T]
    ['F F]
    ['Nat Nat]
    ['PosInt PosInt]
    ['NegInt NegInt]
    ['UInt8 UInt8]
    ['UInt16 UInt16]
    ['UInt32 UInt32]
    ['Int8 Int8]
    ['Int16 Int16]
    ['Int32 Int32]
    [`(Prod ,l ,r) (-prod-type (->Type l) (->Type r))]
    [`(Arrow ,dom ,rng) (-arrow-type (->Type dom) (->Type rng))]
    [`(Or . ,ts) (Or* (map ->Type ts))]
    [`(And . ,ts) (And* (map ->Type ts))]
    [`(Not ,t) (Not (->Type t))]))
