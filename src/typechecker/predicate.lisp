(defpackage #:coalton-impl/typechecker/predicate
  (:use
   #:cl
   #:coalton-impl/typechecker/kinds
   #:coalton-impl/typechecker/types
   #:coalton-impl/typechecker/substitutions)
  (:local-nicknames
   (#:util #:coalton-impl/util))
  (:export
   #:ty-predicate                       ; STRUCT
   #:make-ty-predicate                  ; CONSTRUCTOR
   #:ty-predicate-class                 ; ACCESSOR
   #:ty-predicate-types                 ; ACCESSOR
   #:ty-predicate-p                     ; FUNCTION
   #:ty-predicate-list                  ; TYPE
   #:qualified-ty                       ; STRUCT
   #:make-qualified-ty                  ; CONSTRUCTOR
   #:qualified-ty-predicates            ; ACCESSOR
   #:qualified-ty-type                  ; ACCESSOR
   #:static-predicate-p                 ; FUNCTION
   #:qualify                            ; FUNCTION
   #:pprint-predicate                   ; FUNCTION
   ))

(in-package #:coalton-impl/typechecker/predicate)

;;;
;;; Type predicates
;;;

(defstruct ty-predicate
  "A type predicate indicating that TYPE is of the CLASS"
  (class (util:required 'class) :type symbol  :read-only t)
  (types (util:required 'types) :type ty-list :read-only t))

(defmethod make-load-form ((self ty-predicate) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-predicate))

(defun ty-predicate-list-p (x)
  (and (alexandria:proper-list-p x)
       (every (lambda (b) (typep b 'ty-predicate)) x)))

(deftype ty-predicate-list ()
  "A list of type predicates"
  `(satisfies ty-predicate-list-p))

(defun static-predicate-p (pred)
  "Is PRED a static predicate (no type variables)"
  (endp (type-variables (ty-predicate-types pred))))

;;;
;;; Qualified types
;;;

(defstruct (qualified-ty)
  (predicates (util:required 'predicates) :type ty-predicate-list :read-only t)
  (type       (util:required 'type)       :type ty                :read-only t))

(defmethod make-load-form ((self qualified-ty) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type qualified-ty))

(defun qualify (predicates type)
  "Qualify TYPE with PREDICATES"
  (declare (type ty type)
           (type ty-predicate-list predicates)
           (values qualified-ty &optional))
  (make-qualified-ty
   :predicates predicates
   :type type))

;;;
;;; Methods
;;;

(defmethod apply-substitution (subst-list (type ty-predicate))
  (declare (type substitution-list subst-list)
           (values ty-predicate &optional))
  (make-ty-predicate
   :class (ty-predicate-class type)
   :types (apply-substitution subst-list (ty-predicate-types type))))

(defmethod apply-ksubstitution (subs (type ty-predicate))
  (declare (type ksubstitution-list subs))
  (make-ty-predicate
   :class (ty-predicate-class type)
   :types (apply-ksubstitution subs (ty-predicate-types type))))

(defmethod type-variables ((type ty-predicate))
  (type-variables (ty-predicate-types type)))

(defmethod kind-variables ((type ty-predicate))
  (declare (values kyvar-list &optional))
  (mapcan #'kind-variables (ty-predicate-types type)))

(defmethod instantiate (types (type ty-predicate))
  (make-ty-predicate
   :class (ty-predicate-class type)
   :types (instantiate types (ty-predicate-types type))))

(defmethod apply-substitution (subst-list (type qualified-ty))
  (declare (type substitution-list subst-list))
  (make-qualified-ty
   :predicates (apply-substitution subst-list (qualified-ty-predicates type))
   :type (apply-substitution subst-list (qualified-ty-type type))))

(defmethod apply-ksubstitution (subs (type qualified-ty))
  (declare (type ksubstitution-list subs))
  (make-qualified-ty
   :predicates (apply-ksubstitution subs (qualified-ty-predicates type))
   :type (apply-ksubstitution subs (qualified-ty-type type))))

(defmethod type-variables ((type qualified-ty))
  (remove-duplicates
   (append (type-variables (qualified-ty-predicates type))
           (type-variables (qualified-ty-type type)))
   :test #'equalp))

(defmethod kind-variables ((type qualified-ty))
  (declare (values kyvar-list &optional))
  (append
   (kind-variables (qualified-ty-type type))
   (mapcan #'kind-variables (qualified-ty-predicates type))))

(defmethod instantiate (types (type qualified-ty))
  (make-qualified-ty
   :predicates (instantiate types (qualified-ty-predicates type))
   :type (instantiate types (qualified-ty-type type))))

(defmethod kind-of ((type qualified-ty))
  (kind-of (qualified-ty-type type)))

(defmethod function-type-p ((type qualified-ty))
  (function-type-p (qualified-ty-type type)))

(defmethod function-return-type ((type qualified-ty))
  (qualify nil (function-return-type (qualified-ty-type type))))

(defmethod function-type-arguments ((type qualified-ty))
  (function-type-arguments (qualified-ty-type type)))

;;;
;;; Pretty printing
;;;

(defun pprint-predicate (stream predicate &optional colon-p at-sign-p)
  (declare (type stream stream)
           (type ty-predicate predicate)
           (ignore colon-p)
           (ignore at-sign-p)
           (values ty-predicate &optional))
  (write (ty-predicate-class predicate) :stream stream)
  (loop :for ty :in (ty-predicate-types predicate)
        :do (write-char #\space stream)
            (write ty :stream stream))
  predicate)

(set-pprint-dispatch 'ty-predicate 'pprint-predicate)


(defun pprint-qualified-ty (stream qualified-ty &optional colon-p at-sign-p)
  (declare (ignore colon-p)
           (ignore at-sign-p))
  (cond
    ((= 0 (length (qualified-ty-predicates qualified-ty)))
     (write (qualified-ty-type qualified-ty) :stream stream))

    ((= 1 (length (qualified-ty-predicates qualified-ty)))
     (write (first (qualified-ty-predicates qualified-ty))
            :stream stream)
     (write-string (if *coalton-print-unicode*
                          " ⇒ "
                          " => ")
                   stream)
     (write (qualified-ty-type qualified-ty)
            :stream stream))
    (t
     (dolist (pred (qualified-ty-predicates qualified-ty))
       (write-string "(" stream)
       (write pred :stream stream)
       (write-string ") " stream))
     (write-string (if *coalton-print-unicode*
                          "⇒ "
                          "=> ")
                   stream)
     (write (qualified-ty-type qualified-ty) :stream stream)))
  nil)

(set-pprint-dispatch 'qualified-ty 'pprint-qualified-ty)
