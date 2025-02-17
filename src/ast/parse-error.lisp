(defpackage #:coalton-impl/ast/parse-error
  (:use #:cl)
  (:local-nicknames
   (#:util #:coalton-impl/util))
  (:export
   #:coalton-parse-error                ; CONDITION
   #:coalton-parse-error-form           ; ACCESSOR
   #:coalton-parse-error-reason-control ; ACCESSOR
   #:coalton-parse-error-reason-args    ; ACCESSOR
   #:coalton-parse-error-context        ; CONDITION
   #:with-parsing-context               ; MACRO
   #:error-parsing                      ; FUNCTION
   #:coalton-unknown-instance           ; CONDITION
   #:error-unknown-instance             ; FUNCTION
   #:coalton-inherited-symbol           ; CONDITION
   #:error-inherited-symbol             ; FUNCTION
   ))

(in-package #:coalton-impl/ast/parse-error)

(define-condition coalton-parse-error (util:coalton-error)
  ((form :initarg :form
         :reader coalton-parse-error-form)
   (reason-control :initarg :reason-control
                   :reader coalton-parse-error-reason-control)
   (reason-args :initarg :reason-args
                :reader coalton-parse-error-reason-args))
  (:report (lambda (c s)
             (let ((*print-circle* nil))
               (format s "Failed to parse ~S~%~?"
                       (coalton-parse-error-form c)
                       (coalton-parse-error-reason-control c)
                       (coalton-parse-error-reason-args c))))))

(define-condition coalton-parse-error-context (coalton-parse-error)
  ((context :initarg :context
            :reader coalton-parse-error-context
            :type string)
   (suberror :initarg :suberror
             :reader coalton-parse-error-suberror
             :type coalton-parse-error))
  (:documentation "A coalton parse error with additional context")
  (:report
   (lambda (c s)
     (format s "~A~%in ~A"
             (coalton-parse-error-suberror c)
             (coalton-parse-error-context c)))))

(defmacro with-parsing-context ((context &rest args) &body body)
  `(handler-case
       (progn ,@body)
     (util:coalton-error (c)
       (error 'coalton-parse-error-context
              :context (format nil ,context ,@args)
              :suberror c))))

(defun error-parsing (form reason-control &rest reason-args)
  (error 'coalton-parse-error
         :form form
         :reason-control reason-control
         :reason-args reason-args))

(define-condition coalton-unknown-instance (coalton-parse-error)
  ((instance :initarg :instance
             :reader coalton-unknown-instance-instance))
  (:report (lambda (c s)
             (let ((*print-circle* nil))
               (format s "Missing definition for ~A"
                       (coalton-unknown-instance-instance c))))))

(defun error-unknown-instance (instance)
  (error 'coalton-unknown-instance
         :instance instance))

(define-condition coalton-inherited-symbol (error)
  ((symbol :initarg :symbol
           :reader coalton-inherited-symbol-symbol
           :type symbol)
   (package :initarg :package
            :reader coalton-inherited-symbol-package ))
  (:report (lambda (c s)
             (let ((*print-pretty* nil))
               (format s "Unable to define ~a in ~a~%   that symbol was inherited from ~a"
                       (symbol-name (coalton-inherited-symbol-symbol c))
                       (coalton-inherited-symbol-package c) 
                       (symbol-package (coalton-inherited-symbol-symbol c)))))))

(defun error-inherited-symbol (symbol package)
  (error 'coalton-inherited-symbol
         :symbol symbol
         :package package))
