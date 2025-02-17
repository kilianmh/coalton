(in-package #:coalton-impl)

;;;;
;;;; Handling of toplevel COALTON:DEFINE-TYPE.
;;;;

(defun process-toplevel-type-definitions (deftype-forms repr-table env)
  "Returns a list of TYPE-DEFINITIONs, a new ENVIRONMENT, and a list of INSTANCE-DEFINITIONs for Addressable instances."
  (declare (type list deftype-forms)
           (type tc:environment env)
           (values tc:type-definition-list tc:environment list &optional))

  ;; Parse type definitions into a list of TYPE-DEFINITION objects
  (multiple-value-bind (parsed-deftypes env)
      (tc:parse-type-definitions deftype-forms repr-table env)

    (values
     parsed-deftypes
     env
     (loop :for parsed-deftype :in parsed-deftypes
           :for addressable := (maybe-auto-addressable-instance parsed-deftype)
           :when addressable
             :collect addressable))))

;;;
;;; Compiler written instances
;;;

(defun make-auto-addressable-instance (type-def)
  (declare (type tc:type-definition type-def)
           (values list &optional))
  (let* ((name (tc:type-definition-name type-def))
         (tvars (loop :for i :below (tc:kind-arity (tc:tycon-kind (tc:type-definition-type type-def)))
                      :collect (alexandria:format-symbol :keyword "~d" i)))
         (full-type (if tvars
                        `(,name ,@tvars)
                        name))
         (addressable-class
           (alexandria:ensure-symbol "ADDRESSABLE" (find-package "COALTON-LIBRARY/CLASSES")))

         (eq?
           (alexandria:ensure-symbol "EQ?" (find-package "COALTON-LIBRARY/CLASSES"))))
    `(coalton:define-instance (,addressable-class ,full-type)
       (coalton:define (,eq? a b)
         (coalton:lisp coalton:Boolean (a b)
           (eq a b))))))

(defun maybe-auto-addressable-instance (type-def)
  (declare (type tc:type-definition type-def)
           (values list &optional))
  (when (tc:explicit-repr-auto-addressable-p (tc:type-definition-explicit-repr type-def))
    (make-auto-addressable-instance type-def)))
