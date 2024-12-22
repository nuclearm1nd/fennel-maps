(local
  {: idiv
   } (require :generic.math))

(local
  {: mapv
   } (require :generic.list))

(local Set (require :generic.set))

(local coord-index {})
(local coord-proxy {})

(local coord-meta
  {:__index
     (fn [t k]
       (-?> coord-proxy
            (. t)
            (. k)))
   :__newindex
     (fn []
       (error "attempt to update a coordinate" 2))
   :__tostring
     (fn [t]
       (let [[q r] (. coord-proxy t)]
         (.. "[" (tostring q) ";" (tostring r) "]")))})

(lambda get-or-add! [q r]
  (if (not (. coord-index q))
    (tset coord-index q {}))
  (let [inner (. coord-index q)
        crd (. inner r)]
    (if (~= nil crd)
      crd
      (let [proxy [q r]
            new-crd {}]
        (tset inner r new-crd)
        (tset coord-proxy new-crd proxy)
        (setmetatable new-crd coord-meta)
        new-crd))))

(lambda new [t ?r]
  (let [T (type t)]
    (case T
      :table
        (if (~= nil ?r)
          (error "too many arguments to new coordinate")
          (do
            (assert (= 2 (length t))
              "too many arguments to new coordinate")
            (get-or-add! (. t 1) (. t 2))))
      :number
        (do
          (assert (and (~= nil ?r)
                       (= :number (type ?r)))
            "expected a number in second position")
          (get-or-add! t ?r))
      _ (error ("Bad arguments to new coordinate")))))

(lambda is-crd? [t]
  (if (~= :table (type t))
    false
    (= coord-meta (getmetatable t))))

(lambda coalesce [t]
  (if (is-crd? t)
    t
    (new t)))

(lambda to-axial [[x y] ?origin]
  (let [[x0 y0] (or ?origin [0 0])
        q (- x x0)]
    (new
      [q
       (-> y (- y0) (+ (idiv q 2)))])))

(lambda to-oddq [[q r] ?origin]
  (let [[q0 r0] (or ?origin [0 0])
        x (- q q0)]
    (new
      [x
       (- r r0 (idiv x 2))])))

(lambda to-new-origin [[q r] [qo ro]]
  (new
    [(- q qo)
     (- r ro)]))

(lambda symmetric [[q r] ?origin]
  (if (not ?origin)
    (new [(- q) (- r)])
    (let [[qo ro] ?origin]
      (-> [q r]
          (to-new-origin [qo ro])
          symmetric
          (to-new-origin [(- qo) (- ro)])))))

(lambda distance [[q0 r0] ?crd1]
  (let [[q1 r1] (or ?crd1 [0 0])
        q (- q0 q1)
        r (- r0 r1)]
    (idiv (+ (math.abs q)
             (math.abs r)
             (math.abs (- q r)))
          2)))

(lambda point-zone-factory [criterium [q r] ?distance]
  (let [dist (or ?distance 1)
        result (Set.new)]
   (for [dq (- dist) dist 1]
     (for [dr (- dist) dist 1]
       (let [crd (new [(+ q dq) (+ r dr)])
             dst (distance crd [q r])]
         (when (criterium dist dst)
           (result:add! crd)))))
    result))

(local neighbors
  (partial point-zone-factory
    (lambda [max-dist dist]
      (and (> dist 0)
           (<= dist max-dist)))))

(local zone
  (partial point-zone-factory
    (lambda [max-dist dist]
      (<= dist max-dist))))

(lambda belt [min max crd]
  (Set.difference
    (zone crd max)
    (zone crd min)))

(lambda collection-neighbors [collection ?distance]
  (let [dist (or ?distance 1)
        nhbrs (Set.new)
        coll
          (if (Set.is-set? collection)
            collection
            (->> collection
                 (mapv #(coalesce $1))
                 Set.to-set))]
    (each [item (coll:iterator)]
      (each [crd (: (neighbors item dist) :iterator)]
        (nhbrs:add! crd)))
    (nhbrs:difference! coll)))

{
 : new
 : is-crd?
 : coalesce
 : to-axial
 : to-oddq
 : to-new-origin
 : symmetric
 : distance
 : point-zone-factory
 : neighbors
 : zone
 : belt
 : collection-neighbors
 }
