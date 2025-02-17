(in-package #:coalton-impl)

;;; Handling of toplevel COALTON:DEFINE-INSTANCE.

(defun process-toplevel-instance-definitions (definstance-forms package env &key compiler-generated)
  (declare  (values tc:instance-definition-list))

  (mapcar
     (lambda (form)
       (tc:parse-instance-definition form package env :compiler-generated compiler-generated))
     definstance-forms))

(defun predeclare-toplevel-instance-definitions (definstance-forms package env)
  "Predeclare all instance definitions in the environment so values can be typechecked"
  (declare (type list definstance-forms)
           (type package package)
           (type tc:environment env)
           (values tc:environment))

  (loop :for form :in definstance-forms
        :do (multiple-value-bind (predicate context methods)
                (coalton-impl/typechecker::parse-instance-decleration form env)
              (declare (ignore methods))
              (let* ((class-name (tc:ty-predicate-class predicate))

                     (instance-codegen-sym
                       (alexandria:format-symbol
                        package "INSTANCE/~A"
                        (with-output-to-string (s)
                          (tc:with-pprint-variable-context ()
                            (let* ((*print-escape* t))
                              (tc:pprint-predicate s predicate))))))

                     (method-names (mapcar
                                    #'car
                                    (coalton-impl/typechecker::ty-class-unqualified-methods
                                     (coalton-impl/typechecker::lookup-class env class-name))))

                     (method-codegen-syms
                       (let ((table (make-hash-table)))
                         (loop :for method-name :in method-names
                               :do (setf (gethash method-name table)
                                         (alexandria:format-symbol
                                          package
                                          "~A-~S"
                                          instance-codegen-sym
                                          method-name)))
                         table))

                     (instance
                       (tc:make-ty-class-instance
                        :constraints context
                        :predicate predicate
                        :codegen-sym instance-codegen-sym
                        :method-codegen-syms method-codegen-syms)))

                (loop :for key :being :the :hash-keys :of method-codegen-syms
                      :for value :being :the :hash-values :of method-codegen-syms
                      :for codegen-sym := (coalton-impl/typechecker::ty-class-instance-codegen-sym instance)
                      :do (setf env (tc:set-method-inline env key codegen-sym value)))

                (when context
                  (setf env (tc:set-function
                             env
                             instance-codegen-sym
                             (tc:make-function-env-entry
                              :name instance-codegen-sym
                              :arity (length context)))))

                (setf env (tc:add-instance env class-name instance)))))

  env)
