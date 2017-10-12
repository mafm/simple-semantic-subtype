#lang typed/racket/base

(require racket/list
         racket/match
         "base-lang.rkt"
         "set-utils.rkt"
         "tunit.rkt")


(define-type Literal (U Atom (Not Atom)))
(define-predicate Literal? Literal)
(define-type Clause (U Literal (And Literal)))
(define-type DNF (U Clause (Or Clause)))

(: ->DNF (-> Type DNF))
(define (->DNF t)
  (match t
    [(? Literal? l) l]
    [(Not (And ts)) (DNF-Or-Map (λ ([t : Type]) (->DNF (Not t))) ts)]
    [(Not (Or ts)) (DNF-And-map (λ ([t : Type]) (->DNF (Not t))) ts)]
    [(Or ts) (DNF-Or-Map ->DNF ts)]
    [(And ts) (DNF-And-map ->DNF ts)]))

(: literal-negate (-> Literal Literal))
(define (literal-negate l)
  (match l
    [(? Atom? a) (Not a)]
    [(Not a) a]))

(: DNF-And-map (-> (-> Type DNF) (Setof Type) DNF))
(define (DNF-And-map f ts)
  (let loop ([todo : (Setof Type) ts]
             [ors : (Setof (Or Clause)) (set)]
             [result : (Setof Literal) (set)])
    (match todo
      [(list)
       (match ors
         [(list) (if (= 1 (set-count result))
                     (car result)
                     (And result))]
         [(cons (Or or-ts) rst)
          (define and-ts (append rst result))
          (->DNF (Or (map (λ ([t : Type]) (And (set-add and-ts t)))
                          or-ts)))])]
      [(cons (app f t) rst)
       (match t
         [(? Literal? l)
          (loop rst ors (set-add result l))]
         [(And ls)
          (loop rst ors (append ls result))]
         [(? Or? d)
          (loop rst (set-add ors d) result)])])))

(: DNF-Or-Map (-> (-> Type DNF) (Setof Type) DNF))
(define (DNF-Or-Map f ts)
  (let loop ([todo : (Setof Type) ts]
             [result : (Setof Clause) (set)])
    (match todo
      [(list) (if (= 1 (set-count result))
                  (first result)
                  (Or result))]
      [(cons (app f d) rst)
       (cond
         [(Or? d) (loop rst (append (Or-ts d) result))]
         [else (loop rst (set-add result d))])])))

(: subtype? (-> Type Type Boolean))
(define (subtype? t1 t2)
  (uninhabited-DNF?
   (->DNF (And (set t1 (Not t2))))))

(: uninhabited-DNF? (-> DNF Boolean))
(define (uninhabited-DNF? d)
  (match d
    [(? Literal?) #false]
    [(? And? clause) (uninhabitited-DNF-clause? clause)]
    [(Or cs) (forall uninhabitited-DNF-clause? cs)]))

(: uninhabitited-DNF-clause? (-> Clause Boolean))
(define (uninhabitited-DNF-clause? clause)
  (match clause
    [(? Literal?) #false]
    [(And ls)
     (define P (filter Atom? ls))
     (define-values (Ptag Prange Pprod Parrow)
       (extract-positive-literals P))
     (cond
       [(non-empty-set? Ptag)
        (cond
          [(or (non-empty-set? Prange)
               (non-empty-set? Pprod)
               (non-empty-set? Parrow))
           #t]
          [else
           (uninhabitited-Tag-clause? Ptag (filter Not-Tag? ls))])]
       [(non-empty-set? Prange)
        (cond
          [(or (non-empty-set? Pprod)
               (non-empty-set? Parrow))
           #t]
          [else
           (uninhabitited-Range-clause? Prange (filter Not-Range? ls))])]
       [(non-empty-set? Pprod)
        (cond
          [(non-empty-set? Parrow) #t]
          [else
           (uninhabitited-Prod-clause? Pprod (filter Not-Prod? ls))])]
       [(non-empty-set? Parrow)
        (uninhabitited-Arrow-clause? Parrow (filter Not-Arrow? ls))]
       [else #f])]))

(: extract-positive-literals (-> (Setof Atom)
                                 (values (Setof Tag)
                                         (Setof Range)
                                         (Setof Prod)
                                         (Setof Arrow))))
(define (extract-positive-literals P)
  (let loop : (values (Setof Tag)
                      (Setof Range)
                      (Setof Prod)
                      (Setof Arrow))
    ([todo : (Setof Atom) P]
     [Ptag : (Setof Tag) (set)]
     [Prange : (Setof Range) (set)]
     [Pprod : (Setof Prod) (set)]
     [Parrow : (Setof Arrow) (set)])
    (match todo
      [(list) (values Ptag Prange Pprod Parrow)]
      [(cons a as)
       (cond
         [(Tag? a) (loop as (cons a Ptag) Prange Pprod Parrow)]
         [(Range? a) (loop as Ptag (cons a Prange) Pprod Parrow)]
         [(Prod? a) (loop as Ptag Prange (cons a Pprod) Parrow)]
         [else (loop as Ptag Prange Pprod (cons a Parrow))])])))


(: uninhabitited-Tag-clause?
   (-> (Setof Tag) (Setof (Not Tag)) Boolean))
(define (uninhabitited-Tag-clause? P N)
  (cond
    [(< 1 (set-count (remove-duplicates P)))
     #true]
    [else
     (exists (λ ([n : (Not Tag)]) (set-member? P (Not-t n)))
             N)]))

(: uninhabitited-Range-clause?
   (-> (Setof Range) (Setof (Not Range)) Boolean))
(define (uninhabitited-Range-clause? pos neg)
  (uninhabited-range?
   (reduce-range-with-negs
    (combine-ranges pos)
    neg)))


(: uninhabited-range? (-> Range Boolean))
;; is a given range uninhabited
(define (uninhabited-range? r)
  (match-define (Range lower upper) r)
  (and lower upper (> lower upper)))


(: combine-ranges (-> (Setof Range) Range))
;; given a bunch of known ranges, collapse them
;; into a single range
(define (combine-ranges P)
  (let-values
      ([(lower upper)
        (for/fold ([lower : Real -inf.0]
                   [upper : Real +inf.0])
                  ([r (in-set P)])
          (values (max lower (Range-lower r))
                  (min upper (Range-upper r))))])
    (Range lower upper)))


(: reduce-range-with-negs (-> Range (Setof (Not Range)) Range))
;; a sound but incomplete procedure that reduces some
;; range (pos) with a but of ranges that the value is known
;; to not be in. Notably, this function will not "partition"
;; the range, it only shrinks the range.
(define (reduce-range-with-negs r N)
  (define-values (new-lower new-upper)
    (for/fold : (values Real Real)
      ([lower (Range-lower r)]
       [upper (Range-upper r)])
      ([neg (in-set N)])
      (match-define (Not (Range neg-lower neg-upper)) neg)
      (cond
        [(or (< neg-upper lower)
             (> neg-lower upper))
         (values lower upper)]
        [(<= neg-lower lower)
         (cond
           [(>= neg-upper upper) (values +inf.0 -inf.0)]
           [else (values (add1 neg-upper) upper)])]
        [else
         (cond
           [(>= neg-upper upper) (values lower (sub1 neg-lower))]
           [else (values +inf.0 -inf.0)])])))
  (Range new-lower new-upper))



(: uninhabitited-Prod-clause?
   (-> (Setof Prod) (Setof (Not Prod)) Boolean))
(define (uninhabitited-Prod-clause? P N)
  (let ([s1 (And (map Prod-l P))]
        [s2 (And (map Prod-r P))])
    (forall
     (λ ([N* : (Setof (Not Prod))])
       (or (let ([t1 (Or (map (λ ([p : (Not Prod)])
                                (Prod-l (Not-t p)))
                              N*))])
             (subtype? s1 t1))
           (let* ([N-N* (set-diff N N*)]
                  [t2 (Or (map (λ ([p : (Not Prod)])
                                 (Prod-r (Not-t p)))
                               N-N*))])
             (subtype? s2 t2))))
     (subsets N))))



(: uninhabitited-Arrow-clause?
   (-> (Setof Arrow) (Setof (Not Arrow)) Boolean))
(define (uninhabitited-Arrow-clause? P N)
  (let ([dom (Or (map Arrow-dom P))])
    (exists (λ ([na : (Not Arrow)])
              (let ([t1 (Arrow-dom (Not-t na))]
                    [t2 (Arrow-rng (Not-t na))])
                (and (subtype? t1 dom)
                     (forall (λ ([P* : (Setof Arrow)])
                               (or (let ([s1 (Or (map Arrow-dom P*))])
                                     (subtype? t1 s1))
                                   (let ([s2 (And (map Arrow-rng (set-diff P P*)))])
                                     (subtype? s2 t2))))
                             (strict-subsets P)))))
            N)))

(module+ test
  ;; basic tests
  (check-true  (subtype? Int Univ))
  (check-false (subtype? Univ Int))
  (check-true  (subtype? Empty Int))
  (check-true  (subtype? Empty Empty))
  (check-false (subtype? Int Empty))
  
  ;; range tests
  (check-true  (subtype? PosInt Int))
  (check-true  (subtype? NegInt Int))
  (check-false (subtype? Int PosInt))
  (check-false (subtype? Int NegInt))
  (check-false (subtype? PosInt NegInt))
  (check-false (subtype? NegInt PosInt))
  (check-true  (subtype? PosInt Nat))
  (check-true  (subtype? PosInt Nat))
  
  ;; tests with unions
  (check-true  (subtype? Int (Or (set Int Unit))))
  (check-true  (subtype? Int (Or (set Int Bool))))
  (check-true  (subtype? Bool (Or (set Int Bool))))
  (check-true  (subtype? Empty (Or (set Int Bool))))
  (check-true  (subtype? Bool (Or (set Empty Bool))))
  (check-false (subtype? (Or (set Int Unit)) Int))
  (check-false (subtype? Bool Int))
  (check-false (subtype? Int Bool))
  (check-false  (subtype? (Or (set Int Bool)) Empty))
  
  ;; tests with intersections
  (check-true  (subtype? (And (set Int Unit)) Int))
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
  ;(subtype? (Prod Int Int) (Prod Univ Int))
  ;(subtype? (Prod Int Int) (Prod Int Univ))
  ;(subtype? (Prod Int Int) (Prod Int Int))
  ;(subtype? (Prod Int Int) (Prod Empty Int))
  ;(subtype? (Prod Int Int) (Prod Int Empty))
  ;(subtype? (Prod Int Int) (Prod Empty Empty))


  )

