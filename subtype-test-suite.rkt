#lang typed/racket/base

(require "base-lang.rkt"
         "set-utils.rkt"
         "tunit.rkt")

(provide (all-defined-out))

(: run-subtype-tests (-> (-> Type Type Boolean) Void))
(define (run-subtype-tests subtype?)
  ;; basic tests
  (check-true  (subtype? Int Univ))
  (check-true  (subtype? (Not Int) (Not Nat)))
  (check-true  (subtype? (Not Int) (Not NegInt)))
  (check-false (subtype? (Not Nat) (Not Int)))
  (check-false (subtype? (Not NegInt) (Not Int)))
  (check-false (subtype? Univ Int))
  (check-true  (subtype? Empty Int))
  (check-true  (subtype? Empty Empty))
  (check-true  (subtype? (Not Empty) Univ))
  (check-false (subtype? Int Empty))
  
  ;; range tests
  (check-true  (subtype? Int8 Int8))
  (check-true  (subtype? PosInt Int))
  (check-true  (subtype? NegInt Int))
  (check-false (subtype? Int PosInt))
  (check-false (subtype? Int NegInt))
  (check-false (subtype? PosInt NegInt))
  (check-false (subtype? NegInt PosInt))
  (check-false (subtype? Int16 Int8))
  (check-false (subtype? Int32 Int8))
  (check-false (subtype? Int32 Int16))
  (check-true  (subtype? PosInt Nat))
  (check-true  (subtype? PosInt Nat))
  (check-true  (subtype? UInt8 UInt16))
  (check-true  (subtype? UInt8 Int16))
  (check-true  (subtype? Int16 Int32))
  
  ;; tests with unions
  (check-true  (subtype? (Or (set NegInt PosInt)) Int))
  (check-true  (subtype? (Or (set NegInt Nat)) Int))
  (check-false (subtype? Int (Or (set NegInt PosInt))))
  (check-true  (subtype? Int (Or (set NegInt Nat))))
  (check-true  (subtype? Int (Or (set Int Unit))))
  (check-true  (subtype? Int (Or (set Int Bool))))
  (check-true  (subtype? Bool (Or (set Int Bool))))
  (check-true  (subtype? Empty (Or (set Int Bool))))
  (check-true  (subtype? Bool (Or (set Empty Bool))))
  (check-false (subtype? (Or (set Int Unit)) Int))
  (check-false (subtype? Bool Int))
  (check-false (subtype? Int Bool))
  (check-false  (subtype? Bool (Or (set Empty 'True Int32))))
  (check-false (subtype? (Or (set Int Bool)) Empty))
  
  ;; tests with intersections
  (check-true  (subtype? (And (set Int8 Int16)) Int32))
  (check-true  (subtype? (And (set Int32 Int16)) Int32))
  (check-true  (subtype? (And (set Int8 Int16)) (And (set Int8 Int32))))
  (check-true  (subtype? (And (set UInt8 UInt16)) (And (set Int16 Int32))))
  (check-true  (subtype? (And (set UInt8 Int16)) (Or (set Int16 Int32))))
  (check-false (subtype? Int16 (And (set UInt8 Int16))))
  (check-true  (subtype? (And (set UInt8 Int16)) Int16))
  (check-false  (subtype? Int8 (And (set UInt8 Int16))))
  (check-false  (subtype? (And (set UInt8 Int16)) Int8))
  (check-false (subtype? Int32 (And (set UInt8 Int16))))
  (check-false (subtype? (Or (set Int16 Int32)) (And (set UInt8 Int16))))
  (check-true  (subtype? (And (set Int Unit)) Int))
  (check-true  (subtype? (And (set Int Unit (Not Univ))) Int))
  (check-true  (subtype? (And (set Int Bool (Not Bool))) Int))
  (check-true  (subtype? (And (set Int (Not NegInt))) Nat))
  (check-true  (subtype? Nat (And (set Int (Not NegInt)))))
  (check-false (subtype? (And (set Int (Not PosInt))) NegInt))
  (check-true  (subtype? (And (set Int (Not Nat))) NegInt))
  (check-true  (subtype? NegInt (And (set Int (Not PosInt)))))
  (check-true  (subtype? (And (set Int Unit)) Int))
  (check-false (subtype? Int (And (set Int Unit))))
  (check-true  (subtype? (And (set (Or (set Int Unit))
                                   (Or (set Int Bool))))
                         Int))
  (check-true  (subtype? Int
                         (And (set (Or (set Int Unit))
                                   (Or (set Int Bool))))))
  
  ;; tests with products
  (check-true  (subtype? (Prod Int Int) (Prod Univ Univ)))
  (check-true  (subtype? (Prod Empty Int) (Prod Int Int)))
  (check-true  (subtype? (Prod Int Empty) (Prod Int Int)))
  (check-true  (subtype? (Prod Int Int) (Prod Int Univ)))
  (check-true  (subtype? (Prod Int Int) (Prod Univ Int)))
  (check-true  (subtype? (Prod Int Int) (Prod Int Int)))
  (check-false (subtype? (Prod Int Int) (Prod Empty Int)))
  (check-false (subtype? (Prod Int Int) (Prod Int Empty)))
  (check-false (subtype? (Prod Int Int) (Prod Empty Empty)))
  (check-false (subtype? (Prod Int Int) (Prod Bool Int)))
  (check-false (subtype? (Prod Int Int) (Prod Int Bool)))
  (check-true  (subtype? (Prod Int Int) (Prod (Or (set Int Bool)) Int)))
  (check-true  (subtype? (Prod Int Int) (Prod Int (Or (set Int Bool)))))
  (check-false (subtype? (Prod (Or (set Int Bool)) Int)
                         (Prod Int Int)))
  (check-false (subtype? (Prod Int (Or (set Int Bool)))
                         (Prod Int Int)))
  (check-true  (subtype? (And (set (Prod Univ Int)
                                   (Prod Int Univ)))
                         (Prod Int Int)))
  (check-true  (subtype? (Prod Int Int)
                         (And (set (Prod Univ Int)
                                   (Prod Int Univ)))))
  (check-true  (subtype? (Prod Int Int)
                         (And (set (Prod (Or (set Bool Int)) Int)
                                   (Prod (Not Bool) (Or (set Bool Int)))))))
  (check-true  (subtype? (Prod Int Int)
                         (And (set (Prod Univ Int)
                                   (Prod Int Univ)))))
  (check-false (subtype? (Prod (Or (set Int Bool))
                               (Or (set Int Bool)))
                         (Or (set (Prod Int Bool)
                                  (Prod Bool Int)))))
  (check-true (subtype? (Or (set (Prod Int Bool)
                                 (Prod Bool Int)))
                        (Prod (Or (set Int Bool))
                              (Or (set Int Bool)))))
  (check-true (subtype? (Prod (Prod (Or (set Int Bool))
                                    (Or (set Int Bool)))
                              (Prod (Or (set Int Bool))
                                    (Or (set Int Bool))))
                        (Prod (Or (set (Prod Int Int)
                                       (Prod Bool Int)
                                       (Prod Int Bool)
                                       (Prod Bool Bool)))
                              (Or (set (Prod Int Int)
                                       (Prod Bool Int)
                                       (Prod Int Bool)
                                       (Prod Bool Bool))))))
  
  ;; tests with arrows
  (check-true  (subtype? (Arrow Int Int) (Arrow Int Univ)))
  (check-true  (subtype? (Arrow Univ Int) (Arrow Int Univ)))
  (check-false (subtype? (Arrow Int Int) (Arrow Univ Int)))
  (check-false (subtype? (Arrow Int Univ) (Arrow Int Int)))
  (check-true  (subtype? (And (set (Arrow NegInt NegInt)
                                   (Arrow Nat    Nat)))
                         (Arrow Int Int)))
  (check-false  (subtype? (Arrow Int Int)
                          (And (set (Arrow NegInt NegInt)
                                    (Arrow Nat    Nat)))))
  (display-test-results))






;; a disjoint Union of size 16
(define SomeBase (Or (set 'True
                          'False
                          'String
                          'Symbol
                          Int8
                          Int16
                          (Arrow Int8 Int8)
                          (Arrow Int16 Int16))))

;; the powerset of the elements of SomeBase
(define 2^SomeBase : (Listof (Or Type))
  (map (inst Or Type) (subsets (Or-ts SomeBase))))

;; The supertype of any product of SomeBase types
(define UnivBaseProd (Prod SomeBase SomeBase))

;; the cartesian product of SomeBase
;; i.e. all products t1 × t2 where t1,t2 ∈ SomeBase
(define SomeBase×SomeBase
  (for*/list : (Setof Type)
    ([t1 (in-set (Or-ts SomeBase))]
     [t2 (in-set (Or-ts SomeBase))])
    (Prod t1 t2)))

;; the cartesian product of SomeBase
;; i.e. all products t1 × t2 where t1,t2 ∈ SomeBase
(define SomeBase→SomeBase
  (for*/list : (Setof Type)
    ([t1 (in-set (Or-ts SomeBase))]
     [t2 (in-set (Or-ts SomeBase))])
    (Prod t1 t2)))

(define misc-prods (set UnivBaseProd
                        (Prod 'Symbol (Or (set Int8 'Symbol)))
                        (Prod (Or (set 'Symbol Bool)) Int8)
                        (Prod (Or (set 'Symbol Int16))
                              Int8)
                        (Prod Int8
                              (Or (set 'Symbol Int16)))
                        (Prod (Arrow Int8 Int8)
                              (Arrow Int8 Int8))))
(define 2^misc-prods (map (inst Or Type) (subsets misc-prods)))

(define misc-arrows (set UnivArrow
                         (Arrow 'Symbol (Or (set Int8 'Symbol)))
                         (Arrow (Or (set 'Symbol Bool)) Int8)
                         (Arrow (Or (set 'Symbol Int16))
                                Int8)
                         (Arrow Int8
                                (Or (set 'Symbol Int16)))
                         (Arrow (Arrow Int8 Int8)
                                (Arrow Int8 Int8))))
(define 2^misc-arrows (map (inst Or Type) (subsets misc-prods)))


(: ->nat (-> Boolean Natural))
(define (->nat b) (if b 1 0))

(: run-subtype-benchmark (-> String (-> Type Type Boolean) Void))
(define (run-subtype-benchmark name subtype?)
  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: simple unions (size <= 8)\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([disj1 (in-list 2^SomeBase)]
                   [disj2 (in-list 2^SomeBase)])
                  (+ (->nat (subtype? disj1 disj2))
                     (->nat (subtype? disj2 disj1))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: products of simple types\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([prod1 (in-list SomeBase×SomeBase)]
                   [prod2 (in-list SomeBase×SomeBase)])
                  (+ (->nat (subtype? prod1 prod2))
                     (->nat (subtype? prod2 prod1))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: products of unions (size <= 8)\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([t1 (in-list 2^SomeBase)]
                   [t2 (in-list 2^SomeBase)])
                  (+ (->nat (subtype? (Prod t1 t2) (Prod t2 t1)))
                     (->nat (subtype? (Prod t1 t2) (Prod t2 t1)))
                     (->nat (subtype? (Prod t1 t2) UnivBaseProd))
                     (->nat (subtype? UnivBaseProd (Prod t1 t2)))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: unions of products of unions (misc)\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([t1 (in-list 2^misc-prods)]
                   [t2 (in-list 2^misc-prods)])
                  (+ (->nat (subtype? t1 t2))
                     (->nat (subtype? t2 t1))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: arrows of simple types\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([arrow1 (in-list SomeBase→SomeBase)]
                   [arrow2 (in-list SomeBase→SomeBase)])
                  (+ (->nat (subtype? arrow1 arrow2))
                     (->nat (subtype? arrow2 arrow1))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: arrows of unions (size <= 8)\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([t1 (in-list 2^SomeBase)]
                   [t2 (in-list 2^SomeBase)])
                  (+ (->nat (subtype? (Arrow t1 t2) (Arrow t2 t1)))
                     (->nat (subtype? (Arrow t1 t2) (Arrow t2 t1)))
                     (->nat (subtype? (Arrow t1 t2) UnivArrow))
                     (->nat (subtype? UnivArrow (Arrow t1 t2)))))))

  (collect-garbage)
  (collect-garbage)
  (collect-garbage)
  (printf "~a: unions of Arrows of unions (misc)\n" name)
  (printf "[nat result ~a]\n"
          (time (for*/sum : Natural
                  ([t1 (in-list 2^misc-arrows)]
                   [t2 (in-list 2^misc-arrows)])
                  (+ (->nat (subtype? t1 t2))
                     (->nat (subtype? t2 t1))))))
  )