;;; Input parser
(defun variablep (v)
(and (symbolp v) (char= #\? (char (symbol-name v) 0))))
(defun skolem-variable () (gentemp "SV-"))
(defun skolem-function* (&rest args) (cons (gentemp "SF-") args))
(defun skolem-function (args) (apply #'skolem-function* args))
(defun idp (sym) (and (symbolp sym) (alpha-char-p (char (string sym) 0)) 
                      (not (char= (char (string sym) 0) #\())))
(defun myconstantp (con) (or (numberp con) (idp con)))
(defun tostring (lst) (coerce 'string lst))
(defun myfunctionp (fbf)
  (and (listp fbf) (idp (first fbf)) 
       (notany #'null (mapcar #'termp (rest fbf)))))
(defun predicatep (fbf)
  (or (idp fbf) (myfunctionp fbf)))
(defun termp (fbf)
  (or (myconstantp fbf) (variablep fbf) (myfunctionp fbf)))
(defun negationp (fbf)
  (and (eql (first fbf) 'not) (wffp (second fbf))))
(defun conjunctionp (fbf)
  (and (eql (first fbf) 'and) (wffp (second fbf)) (wffp (third fbf))))
(defun disjunctionp (fbf)
  (and (eql (first fbf) 'or) (wffp (second fbf)) (wffp (third fbf))))
(defun implicationp (fbf)
  (and (eql (first fbf) 'implies) (wffp (second fbf)) (wffp (third fbf))))
(defun universalp (fbf) 
  (and (eql (first fbf) 'every) (variablep (second fbf)) (wffp (third fbf))))
(defun existentialp (fbf) 
  (and (eql (first fbf) 'exist) (variablep (second fbf)) (wffp (third fbf))))
(defun wffp (fbf)
  (or (predicatep fbf) (negationp fbf) (conjunctionp fbf)
      (disjunctionp fbf) (implicationp fbf)
      (universalp fbf) (existentialp fbf)))
;;;

(defun as-cnf (fbf) ; WFF to CNF
  (distribute-and (conjunctify fbf)))

(defun remove-imp (fbf)       ; (a -> b) --> (or (not a) b)
  (list 'or (list 'not (second fbf)) (third fbf))) 

; (not (not wff)) -> wff
; + De Morgan laws
; + Bring (exist, every) out
(defun simplify-neg (fbf)     
  (cond
   ((eql (first (second fbf)) 'not) (second (second fbf)))
   ((eql (first (second fbf)) 'and) (list 'or (list 'not (second (second fbf))) 
                                          (list 'not (third (second fbf)))))
   ((eql (first (second fbf)) 'or) (list 'and (list 'not (second (second fbf))) 
                                         (list 'not (third (second fbf)))))
   ((eql (first (second fbf)) 'implies) (list 'not (remove-imp (second fbf))))
   ((eql (first (second fbf)) 'every) 
    (list 'exist (second (second fbf)) 
          (list 'not (list (first (third (second fbf))) 
                           (second (second fbf))))))
   ((eql (first (second fbf)) 'exist) 
    (list 'every (second (second fbf)) 
          (list 'not (list (first (third (second fbf))) 
                           (second (second fbf))))))
   ((or (idp fbf) (termp fbf)) fbf)
   (T (error "Syntax error"))))

(defun conjunctify (fbf) ; Get WFF ready to distribute ands
  (cond
   ((atom fbf) fbf)
   ((listp (first fbf)) 
    (append (list (conjunctify (first fbf))) (conjunctify (rest fbf))))
   ((not (wffp fbf)) (error "Syntax error"))
   ((eql (first fbf) 'implies) (conjunctify (remove-imp fbf)))
   ((and (eql (first fbf) 'not) (listp (second fbf))) 
    (conjunctify (simplify-neg fbf)))
   ((eql (first fbf) 'not) (list 'not (second fbf))) 
   ((eql (first fbf) 'and) (append (list 'and) 
                                   (list (conjunctify (first (rest fbf))))
                                   (list (conjunctify (second (rest fbf))))))
   ((eql (first fbf) 'or)   
    (if
        (or (and (listp (second (distribute fbf))) 
                 (eql (first (second (distribute fbf))) 'and))
            (and (listp (third (distribute fbf)))
                 (eql (first (third (distribute fbf))) 'and)))
        (conjunctify (distribute fbf))
      (distribute fbf)))
					; (or c (and a b))     ->  (and (or c a) (or c b))
                                        ; (or (and a b) c)     ->  (and (or c a) (or b c))
                                        ; (or w (or f (foo 42)) -> (or w f (foo 42))
   ((and (eql (first fbf) 'exist) (variablep (second fbf)))
    (conjunctify (replace-vars (third fbf) (second fbf) (skolem-variable))))
   ((and (eql (first fbf) 'every) (variablep (second fbf))) 
    (conjunctify (skolemize (third fbf) 
                            (skolem-function (list (second fbf))))))
   ((or (eql (first fbf) 'every) (eql (first fbf) 'exist))
    (error "Syntax Error"))
   (T fbf)))

; (or p (and q w)) -> (and (or p q) (or p w))
(defun distribute (fbf)
  (cond
   ((null fbf) fbf)
   ((atom fbf) fbf)
   ((and (listp (second fbf)) (eql (first (second fbf)) 'and)) 
    (conjunctify (list 'and (list 'or (second (second fbf)) (third fbf))
                       (list 'or (third (second fbf)) (third fbf)))))
   ((and (listp (third fbf)) (eql (first (third fbf)) 'and))  
    (conjunctify (list 'and (list 'or (second fbf) (second (third fbf)))
                       (list 'or (second fbf) (third (third fbf))))))
   (T   (append (list 'or) (test (conjunctify (rest fbf)))))))

; (and a (and b c)) -> (and a b c)
(defun distribute-and (fbf)
  (cond
   ((null fbf) fbf)
   ((atom fbf) fbf)
   ((and (listp (first fbf)) (eql (first (first fbf)) 'and)) 
    (append (distribute-and (rest (first fbf))) (distribute-and (rest fbf))))
   (T (cons (first fbf) (distribute-and (conjunctify (rest fbf)))))))

; (or a (or b c)) -> (or a b c)
(defun test (fbf)  
  (cond
   ((and (listp (first fbf)) (eql (first (first fbf)) 'or)) 
    (append  (test (rest (first fbf))) (test (rest fbf))))
   ((null fbf) fbf)
   (T (cons (first fbf) (test (conjunctify (rest fbf)))))))

(defun replace-vars (fbf var skv)
  (cond
   ((null fbf) fbf)
   ((listp (first fbf)) 
    (append (list (replace-vars (first fbf) var skv)) 
            (replace-vars (rest fbf) var skv)))
   ((and (variablep (first fbf)) (eql (first fbf) var)) 
    (cons skv (rest fbf)))
   (T (cons (first fbf) (replace-vars (rest fbf) var skv)))))

(defun skolemize (fbf fun)
  (cond
   ((and (eql (first fbf) 'every) (variablep (second fbf)))
    (skolemize (third fbf) (append fun (list (second fbf)))))
   ((and (eql (first fbf) 'exist) (variablep (second fbf))) 
    (conjunctify (replace-fun (third fbf) (second fbf) fun)))
   ((or (eql (first fbf) 'every) (eql (first fbf) 'exist)) 
    (error "Syntax Error"))
   (T fbf)))

; Replace existential variable with Skolem-function
(defun replace-fun (fbf var skf) 
  (cond
    ((null fbf) fbf)
    ((and (variablep (first fbf)) (eql (first fbf) var)) 
     (append (list skf) (replace-fun (rest fbf) var skf)))
    ((listp (first fbf)) 
     (append (list (replace-fun (first fbf) var skf))
             (replace-fun (rest fbf) var skf)))
    (T (cons (first fbf) (replace-fun (rest fbf) var skf)))))

; Count positive literals
(defun is-horn (fbf)  
  (let ((cnf (as-cnf fbf)))
    (cond
     ((not (eql (first cnf) 'or)) NIL)
     (T (if (< (count-positive (rest cnf)) 2) T NIL)))))

(defun count-positive (fbf)
  (cond
   ((null fbf) 0)
   ((and (listp (first fbf)) (eql (first (first fbf)) 'not)) 
    (count-positive (rest fbf)))
   ((listp (first fbf)) (+ 1 (count-positive (rest  fbf))))
   (T (+ 1 (count-positive (rest fbf))))))
