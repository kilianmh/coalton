(defpackage #:coalton-impl/typechecker/environment
  (:use
   #:cl
   #:coalton-impl/algorithm
   #:coalton-impl/typechecker/type-errors
   #:coalton-impl/typechecker/types
   #:coalton-impl/typechecker/predicate
   #:coalton-impl/typechecker/scheme
   #:coalton-impl/typechecker/unify
   #:coalton-impl/typechecker/equality)
  (:import-from
   #:coalton-impl/typechecker/substitutions
   #:apply-substitution
   #:substitution-list)
  (:local-nicknames
   (#:util #:coalton-impl/util))
  (:export
   #:value-environment                      ; STRUCT
   #:explicit-repr                          ; TYPE
   #:explicit-repr-auto-addressable-p       ; FUNCTION
   #:explicit-repr-explicit-addressable-p   ; FUNCTION
   #:type-entry                             ; STRUCT
   #:make-type-entry                        ; CONSTRUCTOR
   #:type-entry-name                        ; ACCESSOR
   #:type-entry-runtime-type                ; ACCESSOR
   #:type-entry-type                        ; ACCESSOR
   #:type-entry-explicit-repr               ; ACCESSOR
   #:type-entry-enum-repr                   ; ACCESSOR
   #:type-entry-newtype                     ; ACCESSOR
   #:type-entry-docstring                   ; ACCESSOR 
   #:type-entry-location                    ; ACCESSOR
   #:type-environment                       ; STRUCT
   #:constructor-entry                      ; STRUCT
   #:make-constructor-entry                 ; ACCESSOR
   #:constructor-entry-name                 ; ACCESSOR
   #:constructor-entry-arity                ; ACCESSOR
   #:constructor-entry-constructs           ; ACCESSOR
   #:constructor-entry-classname            ; ACCESSOR
   #:constructor-entry-compressed-repr      ; ACCESSOR
   #:constructor-entry-list                 ; TYPE
   #:constructor-environment                ; STRUCT
   #:ty-class                               ; STRUCT
   #:make-ty-class                          ; CONSTRUCTOR
   #:ty-class-name                          ; ACCESSOR
   #:ty-class-predicate                     ; ACCESSOR
   #:ty-class-superclasses                  ; ACCESSOR
   #:ty-class-unqualified-methods           ; ACCESSOR
   #:ty-class-codegen-sym                   ; ACCESSOR
   #:ty-class-superclass-dict               ; ACCESSOR
   #:ty-class-superclass-map                ; ACCESSOR
   #:ty-class-docstring                     ; ACCESSOR
   #:ty-class-location                      ; ACCESSOR
   #:ty-class-list                          ; TYPE
   #:class-environment                      ; STRUCT
   #:ty-class-instance                      ; STRUCT
   #:make-ty-class-instance                 ; CONSTRUCTOR
   #:ty-class-instance-constraints          ; ACCESSOR
   #:ty-class-instance-predicate            ; ACCESSOR
   #:ty-class-instance-codegen-sym          ; ACCESSOR
   #:ty-class-instance-method-codegen-syms  ; ACCESSOR
   #:ty-class-instance-list                 ; TYPE
   #:instance-environment                   ; STRUCT
   #:instance-environment-instances         ; ACCESSOR
   #:function-env-entry                     ; STRUCT
   #:make-function-env-entry                ; CONSTRUCTOR
   #:function-env-entry-name                ; ACCESSOR
   #:function-env-entry-arity               ; ACCESSOR
   #:function-environment                   ; STRUCT
   #:name-entry                             ; STRUCT
   #:make-name-entry                        ; CONSTRUCTOR
   #:name-entry-name                        ; ACCESSOR
   #:name-entry-type                        ; ACCESSOR
   #:name-entry-docstring                   ; ACCESSOR
   #:name-entry-location                    ; ACCESSOR
   #:name-environment                       ; STRUCT
   #:method-inline-environment              ; STRUCT
   #:code-environment                       ; STRUCT
   #:specialization-entry                   ; STRUCT
   #:make-specialization-entry              ; CONSTRUCTOR
   #:specialization-entry-from              ; ACCESSOR
   #:specialization-entry-to                ; ACCESSOR
   #:specialization-entry-to-ty             ; ACCESSOR
   #:specialization-entry-list              ; TYPE
   #:specialization-environment             ; STRUCT
   #:environment                            ; STRUCT
   #:make-default-environment               ; FUNCTION
   #:environment-value-environment          ; ACCESSOR
   #:environment-type-environment           ; ACCESSOR
   #:environment-constructor-environment    ; ACCESSOR
   #:environment-class-environment          ; ACCESSOR
   #:environment-instance-environment       ; ACCESSOR
   #:environment-function-environment       ; ACCESSOR
   #:environment-name-environment           ; ACCESSOR
   #:environment-method-inline-environment  ; ACCESSOR
   #:environment-code-environment           ; ACCESSOR
   #:environment-specialization-environment ; ACCESSOR
   #:lookup-value-type                      ; FUNCTION
   #:set-value-type                         ; FUNCTION
   #:lookup-type                            ; FUNCTION
   #:set-type                               ; FUNCTION
   #:lookup-constructor                     ; FUNCTION
   #:set-constructor                        ; FUNCTION
   #:lookup-class                           ; FUNCTION
   #:set-class                              ; FUNCTION
   #:lookup-function                        ; FUNCTION
   #:set-function                           ; FUNCTION
   #:unset-function                         ; FUNCTION
   #:lookup-name                            ; FUNCTION
   #:set-name                               ; FUNCTION
   #:lookup-class-instances                 ; FUNCTION
   #:lookup-class-instance                  ; FUNCTION
   #:lookup-instance-by-codegen-sym         ; FUNCTION
   #:lookup-function-source-parameter-names ; FUNCTION
   #:set-function-source-parameter-names    ; FUNCTION
   #:unset-function-source-parameter-names  ; FUNCTION
   #:push-value-environment                 ; FUNCTION
   #:push-type-environment                  ; FUNCTION
   #:push-constructor-environment           ; FUNCTION
   #:push-function-environment              ; FUNCTION
   #:constructor-arguments                  ; FUNCTION
   #:add-class                              ; FUNCTION
   #:add-instance                           ; FUNCTION
   #:set-method-inline                      ; FUNCTION
   #:lookup-method-inline                   ; FUNCTION
   #:set-code                               ; FUNCTION
   #:lookup-code                            ; FUNCTION
   #:add-specialization                     ; FUNCTION
   #:lookup-specialization                  ; FUNCTION
   #:lookup-specialization-by-type          ; FUNCTION
   ))

(in-package #:coalton-impl/typechecker/environment)

;;;
;;; Value type environments
;;;

(defstruct (value-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type value-environment))

(defmethod apply-substitution (subst-list (env value-environment))
  (make-value-environment :data (fset:image (lambda (key value)
                  (values key (apply-substitution subst-list value)))
                (immutable-map-data env))))

(defmethod type-variables ((env value-environment))
  (let ((out nil))
    (fset:do-map (name type (immutable-map-data env))
      (declare (ignore name))
      (setf out (append (type-variables type) out)))
    (remove-duplicates out :test #'equalp)))

;;;
;;; Type environments
;;;

(deftype explicit-repr ()
  '(or null
    (member :enum :lisp :transparent)
    (cons (eql :native) (cons t null))))

(defun explicit-repr-auto-addressable-p (explicit-repr)
  (declare (explicit-repr explicit-repr)
           (values list &optional))
  (member explicit-repr
          '(:lisp :enum)
          :test #'eq))

(defun explicit-repr-explicit-addressable-p (explicit-repr)
  (declare (explicit-repr explicit-repr)
           (values boolean &optional))
  (and (consp explicit-repr)
       (eq (first explicit-repr) :native)))

(defstruct type-entry 
  (name         (util:required 'name)         :type symbol  :read-only t)
  (runtime-type (util:required 'runtime-type) :type t       :read-only t)
  (type         (util:required 'type)         :type ty      :read-only t)

  ;; An explicit repr defined in the source, or nil if none was supplied. Computed repr will be reflected in
  ;; ENUM-REPR, NEWTYPE, and/or RUNTIME-TYPE.
  (explicit-repr (util:required 'explicit-repr)
                                         :type explicit-repr
                                                       :read-only t)

  ;; If this is true then the type is compiled to a more effecient
  ;; enum representation at runtime
  (enum-repr (util:required 'enum-repr)       :type boolean :read-only t)

  ;; If this is true then the type does not exist at runtime
  ;; See https://wiki.haskell.org/Newtype
  ;;
  ;; A type cannot be both enum repr and a newtype
  ;;
  ;; A type that is a newtype has another Coalton type as it's
  ;; runtime-type instead of a lisp type. This is to avoid issues with
  ;; recursive newtypes.
  (newtype (util:required 'newtype)           :type boolean :read-only t)

  (docstring (util:required 'docstring)       :type (or null string) :read-only t)
  (location  (util:required 'location)        :type t                :read-only t))

(defmethod make-load-form ((self type-entry) &optional env)
  (make-load-form-saving-slots self :environment env))

(defmethod kind-of ((entry type-entry))
  (kind-of (type-entry-type entry)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type type-entry))

(defstruct (type-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type type-environment))


(defun make-default-type-environment ()
  "Create a TYPE-ENVIRONMENT containing early types"
  (make-type-environment
   :data (fset:map
          ;; Early Types
          ('coalton:Boolean
           (make-type-entry
            :name 'coalton:Boolean
            :runtime-type 'cl:boolean
            :type *boolean-type*
            :explicit-repr '(:native cl:boolean)
            :enum-repr t
            :newtype nil
            :docstring "Either true or false represented by `t` and `nil` respectively."
            :location ""))

          ('coalton:Char
           (make-type-entry
            :name 'coalton:Char
            :runtime-type 'cl:character
            :type *char-type*
            :explicit-repr '(:native cl:character)
            :enum-repr nil
            :newtype nil
            :docstring "A single character represented as a `character` type."
            :location ""))

          ('coalton:Integer
           (make-type-entry
            :name 'coalton:Integer
            :runtime-type 'cl:integer
            :type *integer-type*
            :explicit-repr '(:native cl:integer)
            :enum-repr nil
            :newtype nil
            :docstring "Unbound integer. Uses `integer`."
            :location ""))

          ('coalton:Single-Float
           (make-type-entry
            :name 'coalton:Single-Float
            :runtime-type 'cl:single-float
            :type *single-float-type*
            :explicit-repr '(:native cl:single-float)
            :enum-repr nil
            :newtype nil
            :docstring "Single precision floating point numer. Uses `single-float`."
            :location ""))

          ('coalton:Double-Float
           (make-type-entry
            :name 'coalton:Double-Float
            :runtime-type 'cl:double-float
            :type *double-float-type*
            :explicit-repr '(:native cl:double-float)
            :enum-repr nil
            :newtype nil
            :docstring "Double precision floating point numer. Uses `double-float`."
            :location ""))

          ('coalton:String
           (make-type-entry
            :name 'coalton:String
            :runtime-type 'cl:string
            :type *string-type*
            :explicit-repr '(:native cl:string)
            :enum-repr nil
            :newtype nil
            :docstring "String of characters represented by Common Lisp `string`."
            :location ""))

          ('coalton:Fraction
           (make-type-entry
            :name 'coalton:Fraction
            :runtime-type 'cl:rational
            :type *fraction-type*
            :explicit-repr '(:native cl:rational)
            :enum-repr nil
            :newtype nil
            :docstring "A ratio of integers always in reduced form."
            :location ""))

          ('coalton:Arrow
           (make-type-entry
            :name 'coalton:Arrow
            :runtime-type nil
            :type *arrow-type*
            :explicit-repr nil
            :enum-repr nil
            :newtype nil
            :docstring "Type constructor for function types."
            :location ""))

          ('coalton:List
           (make-type-entry
            :name 'coalton:List
            :runtime-type 'cl:list
            :type *list-type*
            :explicit-repr '(:native cl:list)
            :enum-repr nil
            :newtype nil
            :docstring "Homogeneous list of objects represented as a Common Lisp `list`."
            :location "")))))

;;;
;;; Constructor environment
;;;

(defstruct constructor-entry
  (name            (util:required 'name)            :type symbol                         :read-only t)
  (arity           (util:required 'arity)           :type alexandria:non-negative-fixnum :read-only t)
  (constructs      (util:required 'constructs)      :type symbol                         :read-only t)
  (classname       (util:required 'classname)       :type symbol                         :read-only t)

  ;; If this constructor constructs a compressed-repr type then
  ;; compressed-repr is the runtime value of this nullary constructor
  (compressed-repr (util:required 'compressed-repr) :type t                              :read-only t))

(defmethod make-load-form ((self constructor-entry) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type constructor-entry))

(defun constructor-entry-list-p (x)
  (and (alexandria:proper-list-p x)
       (every #'constructor-entry-p x)))

(deftype constructor-entry-list ()
  '(satisfies constructor-entry-list-p))

(defstruct (constructor-environment (:include immutable-map)))

(defun make-default-constructor-environment ()
  "Create a TYPE-ENVIRONMENT containing early constructors"
  (make-constructor-environment
   :data (fset:map
          ;; Early Constructors
          ('coalton:True
           (make-constructor-entry
            :name 'coalton:True
            :arity 0
            :constructs 'coalton:Boolean
            :classname 'coalton::Boolean/True
            :compressed-repr 't))

          ('coalton:False
           (make-constructor-entry
            :name 'coalton:False
            :arity 0
            :constructs 'coalton:Boolean
            :classname 'coalton::Boolean/False
            :compressed-repr 'nil))

          ('coalton:Cons
           (make-constructor-entry
            :name 'coalton:Cons
            :arity 2
            :constructs 'coalton:List
            :classname nil
            :compressed-repr 'nil))

          ('coalton:Nil
           (make-constructor-entry
            :name 'coalton:Nil
            :arity 0
            :constructs 'coalton:List
            :classname nil
            :compressed-repr 'nil)))))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type constructor-environment))

;;;
;;; Class environment
;;;

(defstruct ty-class
  (name                (util:required 'name)                :type symbol              :read-only t)
  (predicate           (util:required 'predicate)           :type ty-predicate        :read-only t)
  (superclasses        (util:required 'superclasses)        :type ty-predicate-list   :read-only t)
  ;; Methods of the class containing the same tyvars in PREDICATE for
  ;; use in pretty printing
  (unqualified-methods (util:required 'unqualified-methods) :type scheme-binding-list :read-only t)
  (codegen-sym         (util:required 'codegen-sym)         :type symbol              :read-only t)
  (superclass-dict     (util:required 'superclass-dict)     :type list                :read-only t)
  (superclass-map      (util:required 'superclass-map)      :type hash-table          :read-only t)
  (docstring           (util:required 'docstring)           :type (or null string)    :read-only t)
  (location            (util:required 'location)            :type t                   :read-only t))

(defmethod make-load-form ((self ty-class) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-class))

(defun ty-class-list-p (x)
  (and (alexandria:proper-list-p x)
       (every #'ty-class-p x)))

(deftype ty-class-list ()
  '(satisfies ty-class-list-p))

(defmethod apply-substitution (subst-list (class ty-class))
  (declare (type substitution-list subst-list)
           (values ty-class &optional))
  (make-ty-class
   :name (ty-class-name class)
   :predicate (apply-substitution subst-list (ty-class-predicate class))
   :superclasses (apply-substitution subst-list (ty-class-superclasses class))
   :unqualified-methods (mapcar (lambda (entry)
                                  (cons (car entry)
                                        (apply-substitution subst-list (cdr entry))))
                                (ty-class-unqualified-methods class))
   :codegen-sym (ty-class-codegen-sym class)
   :superclass-dict (mapcar (lambda (entry)
                              (cons (apply-substitution subst-list (car entry))
                                    (cdr entry)))
                            (ty-class-superclass-dict class))
   :superclass-map (ty-class-superclass-map class)
   :docstring (ty-class-docstring class)
   :location (ty-class-location class)))

(defstruct (class-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type class-environment))

;;;
;;; Instance environment
;;;

(defstruct ty-class-instance
  (constraints         (util:required 'constraints)         :type ty-predicate-list :read-only t)
  (predicate           (util:required 'predicate)           :type ty-predicate      :read-only t)
  (codegen-sym         (util:required 'codegen-sym)         :type symbol            :read-only t)
  (method-codegen-syms (util:required 'method-codegen-syms) :type hash-table        :read-only t))

(defmethod make-load-form ((self ty-class-instance) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-class-instance))

(defun ty-class-instance-list-p (x)
  (and (alexandria:proper-list-p x)
       (every #'ty-class-instance-p x)))

(deftype ty-class-instance-list ()
  `(satisfies ty-class-instance-list-p))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type ty-class-instance-list))

(defmethod apply-substitution (subst-list (instance ty-class-instance))
  (declare (type substitution-list subst-list)
           (values ty-class-instance &optional))
  (make-ty-class-instance
   :constraints (apply-substitution subst-list (ty-class-instance-constraints instance))
   :predicate (apply-substitution subst-list (ty-class-instance-predicate instance))
   :codegen-sym (ty-class-instance-codegen-sym instance)
   :method-codegen-syms (ty-class-instance-method-codegen-syms instance)))

(defstruct instance-environment
  (instances    (make-immutable-listmap) :type immutable-listmap :read-only t)
  (codegen-syms (make-immutable-map)     :type immutable-map     :read-only t))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type instance-environment))

;;;
;;; Function environment
;;;

(defstruct function-env-entry
  (name  (util:required 'name)  :type symbol :read-only t)
  (arity (util:required 'arity) :type fixnum :read-only t))

(defmethod make-load-form ((self function-env-entry) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type function-env-entry))

(defun function-env-entry-list-p (x)
  (and (alexandria:proper-list-p x)
       (every #'function-env-entry-p x)))

(deftype function-env-entry-list ()
  `(satisfies function-env-entry-list-p))

(defstruct (function-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type function-environment))

;;;
;;; Name environment
;;;

(defstruct name-entry
  (name      (util:required 'name)      :type symbol                               :read-only t)
  (type      (util:required 'type)      :type (member :value :method :constructor) :read-only t)
  (docstring (util:required 'docstring) :type (or null string)                     :read-only t)
  (location  (util:required 'location)  :type t                                    :read-only t))

(defmethod make-load-form ((self name-entry) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type name-entry))

(defstruct (name-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type name-environment))

;;;
;;; Method Inline environment
;;;

(defstruct (method-inline-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type method-inline-environment))

;;;
;;; Code environment
;;;

(defstruct (code-environment (:include immutable-map)))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type code-environment))

;;;
;;; Specialization Environment
;;;

(defstruct specialization-entry
  (from (util:required 'from)   :type symbol :read-only t)
  (to (util:required 'to)       :type symbol :read-only t)
  (to-ty (util:required 'to-ty) :type ty     :read-only t))

(defmethod make-load-form ((self specialization-entry) &optional env)
  (make-load-form-saving-slots self :environment env))

(defun specialization-entry-list-p (x)
  (and (alexandria:proper-list-p x)
       (every #'specialization-entry-p x)))

(deftype specialization-entry-list ()
  '(satisfies specialization-entry-list-p))

(defstruct (specialization-environment (:include immutable-listmap)))

;;;
;;; Source name environment
;;;
;; maps the names of user-defined functions to a list of their user-supplied parameter names, for
;; documentation generation.

(defstruct (source-name-environment (:include immutable-map)))

;;;
;;; Environment
;;;

(defstruct environment
  (value-environment          (util:required 'value-environment)          :type value-environment          :read-only t)
  (type-environment           (util:required 'type-environment)           :type type-environment           :read-only t)
  (constructor-environment    (util:required 'constructor-environment)    :type constructor-environment    :read-only t)
  (class-environment          (util:required 'class-environment)          :type class-environment          :read-only t)
  (instance-environment       (util:required 'instance-environment)       :type instance-environment       :read-only t)
  (function-environment       (util:required 'function-environment)       :type function-environment       :read-only t)
  (name-environment           (util:required 'name-environment)           :type name-environment           :read-only t)
  (method-inline-environment  (util:required 'method-inline-environment)  :type method-inline-environment  :read-only t)
  (code-environment           (util:required 'code-environment)           :type code-environment           :read-only t)
  (specialization-environment (util:required 'specialization-environment) :type specialization-environment :read-only t)
  (source-name-environment    (util:required 'source-name-environment)    :type source-name-environment    :read-only t))

(defmethod print-object ((env environment) stream)
  (declare (type stream stream)
           (type environment env))
  (print-unreadable-object (env stream :type t :identity t)))


(defmethod make-load-form ((self environment) &optional env)
  (make-load-form-saving-slots self :environment env))

#+(and sbcl coalton-release)
(declaim (sb-ext:freeze-type environment))

(defun make-default-environment ()
  (declare (values environment))
  (make-environment
   :value-environment (make-value-environment)
   :type-environment (make-default-type-environment)
   :constructor-environment (make-default-constructor-environment)
   :class-environment (make-class-environment)
   :instance-environment (make-instance-environment)
   :function-environment (make-function-environment)
   :name-environment (make-name-environment)
   :method-inline-environment (make-method-inline-environment)
   :code-environment (make-code-environment)
   :specialization-environment (make-specialization-environment)
   :source-name-environment (make-source-name-environment)))

(defun update-environment (env
                           &key
                             (value-environment (environment-value-environment env))
                             (type-environment (environment-type-environment env))
                             (constructor-environment (environment-constructor-environment env))
                             (class-environment (environment-class-environment env))
                             (instance-environment (environment-instance-environment env))
                             (function-environment (environment-function-environment env))
                             (name-environment (environment-name-environment env))
                             (method-inline-environment (environment-method-inline-environment env))
                             (code-environment (environment-code-environment env))
                             (specialization-environment (environment-specialization-environment env))
                             (source-name-environment (environment-source-name-environment env)))
  (declare (type environment env)
           (type value-environment value-environment)
           (type constructor-environment constructor-environment)
           (type class-environment class-environment)
           (type instance-environment instance-environment)
           (type function-environment function-environment)
           (type name-environment name-environment)
           (type method-inline-environment method-inline-environment)
           (type code-environment code-environment)
           (type specialization-environment specialization-environment)
           (type source-name-environment source-name-environment)
           (values environment))
  (make-environment
   :value-environment value-environment
   :type-environment type-environment
   :constructor-environment constructor-environment
   :class-environment class-environment
   :instance-environment instance-environment
   :function-environment function-environment
   :name-environment name-environment
   :method-inline-environment method-inline-environment
   :code-environment code-environment
   :specialization-environment specialization-environment
   :source-name-environment source-name-environment))

;;;
;;; Methods
;;;

(defmethod apply-substitution (subst-list (env environment))
  (declare (type substitution-list subst-list)
           (type environment env)
           (values environment &optional))
  (update-environment env
                      :value-environment
                      (apply-substitution
                       subst-list
                       (environment-value-environment env))))

(defmethod type-variables ((env environment))
  (type-variables (environment-value-environment env)))


;;;
;;; Functions
;;;

(defun lookup-value-type (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-value-environment env) symbol)
      (unless no-error
        (let* ((sym-name (symbol-name symbol))
               (valid-bindings (coalton-impl/algorithm::immutable-map-keys (environment-value-environment env)))
               (matches (remove-if-not (lambda (s) (string= (symbol-name s) sym-name)) valid-bindings)))
          (error 'unknown-binding-error :symbol symbol :alternatives matches)))))

(defun set-value-type (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type ty-scheme value)
           (values environment &optional))
  (update-environment
   env
   :value-environment (immutable-map-set
                       (environment-value-environment env)
                       symbol
                       value
                       #'make-value-environment)))

(defun lookup-type (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-type-environment env) symbol)
      (unless no-error
        (let* ((sym-name (symbol-name symbol))
               (valid-types (coalton-impl/algorithm::immutable-map-keys (environment-type-environment env)))
               (matches (remove-if-not (lambda (s) (string= (symbol-name s) sym-name)) valid-types)))
          (cond
            ((= 1 (length sym-name))
             (error "Unknown type ~S. Did you mean the type variable ~S?" symbol (intern sym-name 'keyword)))
            (matches
             (error "Unknown type ~S. Did you mean ~{~S~^, ~}?" symbol matches))
            (t
             (error "Unknown type ~S" symbol)))))))

(defun set-type (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type type-entry value)
           (values environment &optional))
  (update-environment
   env
   :type-environment (immutable-map-set
                       (environment-type-environment env)
                       symbol
                       value
                       #'make-type-environment)))

(defun lookup-constructor (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-constructor-environment env) symbol)
      (unless no-error
        (error "Unknown constructor ~S." symbol))))

(defun set-constructor (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type constructor-entry value)
           (values environment &optional))
  (update-environment
   env
   :constructor-environment (immutable-map-set
                             (environment-constructor-environment env)
                             symbol
                             value
                             #'make-constructor-environment)))

(defun lookup-class (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-class-environment env) symbol)
      (unless no-error
        (error "Unknown class ~S." symbol))))

(defun set-class (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type ty-class value)
           (values environment &optional))
  (update-environment
   env
   :class-environment (immutable-map-set
                       (environment-class-environment env)
                       symbol
                       value
                       #'make-class-environment)))

(defun lookup-function (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-function-environment env) symbol)
      (unless no-error
        (error "Unknown function ~S." symbol))))

(defun set-function (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type function-env-entry value)
           (values environment &optional))
  (update-environment
   env
   :function-environment (immutable-map-set
                          (environment-function-environment env)
                          symbol
                          value
                          #'make-function-environment)))

(defun unset-function (env symbol)
  (declare (type environment env)
           (type symbol symbol))
  (update-environment
   env
   :function-environment (immutable-map-remove
                          (environment-function-environment env)
                          symbol
                          #'make-function-environment)))

(defun lookup-name (env symbol &key no-error)
  (declare (type environment env)
           (type symbol symbol))
  (or (immutable-map-lookup (environment-name-environment env) symbol)
      (unless no-error
        (error "Unknown name ~S." symbol))))

(defun set-name (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type name-entry value)
           (values environment &optional))
  (let ((old-value (lookup-name env symbol :no-error t)))
    (when (and old-value (not (equalp (name-entry-type old-value) (name-entry-type value))))
      (error "Unable to change the type of name ~S from ~A to ~A."
             symbol
             (name-entry-type old-value)
             (name-entry-type value)))
    (if old-value
        env
        (update-environment
         env
         :name-environment (immutable-map-set
                            (environment-name-environment env)
                            symbol
                            value
                            #'make-name-environment)))))

(defun lookup-class-instances (env class &key no-error)
  (declare (type environment env)
           (type symbol class)
           (values fset:seq &optional))
  (immutable-listmap-lookup (instance-environment-instances (environment-instance-environment env)) class :no-error no-error))

(defun lookup-class-instance (env pred &key no-error)
  (declare (type environment env))
  (let* ((pred-class (ty-predicate-class pred))
         (instances (lookup-class-instances env pred-class :no-error no-error)))
    (fset:do-seq (instance instances)
      (handler-case
          (let ((subs (predicate-match (ty-class-instance-predicate instance) pred)))
            (return-from lookup-class-instance (values instance subs)))
        (predicate-unification-error () nil)))
    (unless no-error
      (error "Unknown instance for predicate ~A" pred))))

(defun lookup-instance-by-codegen-sym (env codegen-sym &key no-error)
  (declare (type environment env)
           (type symbol codegen-sym))

  (or (immutable-map-lookup (instance-environment-codegen-syms (environment-instance-environment env)) codegen-sym)
   (unless no-error
     (error "Unknown instance with codegen-sym ~A" codegen-sym))))

(defun lookup-function-source-parameter-names (env function-name)
  (declare (type environment env)
           (type symbol function-name)
           (values util:symbol-list &optional))
  (immutable-map-lookup (environment-source-name-environment env) function-name))

(defun set-function-source-parameter-names (env function-name source-parameter-names)
  (declare (type environment env)
           (type symbol function-name)
           (type util:symbol-list source-parameter-names)
           (values environment &optional))
  (update-environment
   env
   :source-name-environment (immutable-map-set (environment-source-name-environment env)
                                               function-name
                                               source-parameter-names
                                               #'make-source-name-environment)))

(defun unset-function-source-parameter-names (env function-name)
  (declare (type environment env)
           (type symbol function-name)
           (values environment &optional))
  (update-environment
   env
   :source-name-environment (immutable-map-remove (environment-source-name-environment env)
                                                  function-name
                                                  #'make-source-name-environment)))


(defun push-value-environment (env value-types)
  (declare (type environment env)
           (type scheme-binding-list value-types)
           (values environment &optional))
  (update-environment
   env
   :value-environment (immutable-map-set-multiple
                       (environment-value-environment env)
                       value-types
                       #'make-value-environment)))

(defun push-type-environment (env types)
  (declare (type environment env)
           (type list types)
           (values environment &optional))
  (update-environment
   env
   :type-environment (immutable-map-set-multiple
                      (environment-type-environment env)
                      types
                      #'make-type-environment)))

(defun push-constructor-environment (env constructors)
  (declare (type environment env)
           (type constructor-entry-list constructors)
           (values environment &optional))
  (update-environment
   env
   :constructor-environment (immutable-map-set-multiple
                             (environment-constructor-environment env)
                             constructors
                             #'make-constructor-environment)))

(defun push-function-environment (env functions)
  (declare (type environment env)
           (type function-env-entry-list functions)
           (values environment &optional))
  (update-environment
   env
   :function-environment (immutable-map-set-multiple
                          (environment-function-environment env)
                          functions
                          #'make-function-environment)))

(defun constructor-arguments (name env)
  (declare (type symbol name)
           (type environment env)
           (values ty-list &optional))
  (lookup-constructor env name)
  (function-type-arguments (lookup-value-type env name)))

(defun add-class (env symbol value)
  (declare (type environment env)
           (type symbol symbol)
           (type ty-class value)
           (values environment &optional))
  ;; Ensure this class does not already exist
  (when (lookup-class env symbol :no-error t)
    (error "Class ~S already exists." symbol))
  ;; Ensure all super classes exist
  (dolist (sc (ty-class-superclasses value))
    (unless (lookup-class env (ty-predicate-class sc) :no-error t)
      (error "Superclass ~S is not defined." sc)))
  (set-class env symbol value))

(defun add-instance (env class value)
  (declare (type environment env)
           (type symbol class)
           (type ty-class-instance value)
           (values environment &optional))
  ;; Ensure the class is defined
  (unless (lookup-class env class)
    (error "Class ~S does not exist." class))

  (fset:do-seq (inst (lookup-class-instances env class :no-error t) :index index)
    (when (handler-case (or (predicate-mgu (ty-class-instance-predicate value)
                                           (ty-class-instance-predicate inst))
                            t)
            (predicate-unification-error () nil))

      ;; If we have the same instance then simply overwrite the old one
      (if (type-predicate= (ty-class-instance-predicate value)
                           (ty-class-instance-predicate inst))
          (return-from add-instance
            (update-environment
             env
             :instance-environment (make-instance-environment
                                    :instances (immutable-listmap-replace
                                                (instance-environment-instances (environment-instance-environment env))
                                                class
                                                index
                                                value)
                                    :codegen-syms (immutable-map-set
                                                   (instance-environment-codegen-syms (environment-instance-environment env))
                                                   (ty-class-instance-codegen-sym value)
                                                   value))))
          (error 'overlapping-instance-error
                 :inst1 (ty-class-instance-predicate value)
                 :inst2 (ty-class-instance-predicate inst)))))

  (update-environment
   env
   :instance-environment (make-instance-environment
                          :instances (immutable-listmap-push
                                      (instance-environment-instances (environment-instance-environment env))
                                      class
                                      value)
                          :codegen-syms (immutable-map-set
                                        (instance-environment-codegen-syms (environment-instance-environment env))
                                        (ty-class-instance-codegen-sym value)
                                        value))))

(defun set-method-inline (env method instance codegen-sym)
  (declare (type environment env)
           (type symbol method instance codegen-sym)
           (values environment &optional))
  (update-environment
   env
   :method-inline-environment
   (immutable-map-set
    (environment-method-inline-environment env)
    (cons method instance)
    codegen-sym
    #'make-method-inline-environment)))

(defun lookup-method-inline (env method instance &key no-error)
  (declare (type environment env)
           (type symbol method instance)
           (values symbol))
  (or
   (immutable-map-lookup
    (environment-method-inline-environment env)
    (cons method instance))
   (unless no-error
     (error "Unable to find inline method for method ~A on instance ~A." method instance))))

(defun set-code (env name code)
  (declare (type environment env)
           (type symbol name)
           (type t code)
           (values environment &optional))
  (update-environment
   env
   :code-environment
   (immutable-map-set
    (environment-code-environment env)
    name
    code
    #'make-code-environment)))

(defun lookup-code (env name &key no-error)
  (declare (type environment env)
           (type symbol name)
           (values t))
  (or
   (immutable-map-lookup
    (environment-code-environment env)
    name)
   (unless no-error
     (error "Unable to find code for function ~A." name))))

(defun add-specialization (env entry)
  (declare (type environment env)
           (type specialization-entry entry)
           (values environment &optional))

  (let* ((from (specialization-entry-from entry))
         (to (specialization-entry-to entry))
         (to-ty (specialization-entry-to-ty entry)))

    (fset:do-seq (elem (immutable-listmap-lookup (environment-specialization-environment env) from :no-error t) :index index)
      (when (type= to-ty (specialization-entry-to-ty elem))
        (return-from add-specialization
          (update-environment env
                              :specialization-environment
                              (immutable-listmap-replace
                               (environment-specialization-environment env)
                               from
                               index
                               entry
                               #'make-specialization-environment))))

      (handler-case
          (progn
            (unify nil to-ty (specialization-entry-to-ty elem))
            (with-pprint-variable-context ()
              (error "Invalid overlapping specialization for function ~A.~%Specialization target ~A with type ~A~%overlapps ~A with type ~A"
                     from
                     to
                     to-ty
                     (specialization-entry-to elem)
                     (specialization-entry-to-ty elem))))
        (coalton-type-error (e)
          (declare (ignore e)))))

    (update-environment env
                        :specialization-environment
                        (immutable-listmap-push
                         (environment-specialization-environment env)
                         from
                         entry
                         #'make-specialization-environment))))

(defun lookup-specialization (env from to &key (no-error nil))
  (declare (type environment env)
           (type symbol from)
           (type symbol to)
           (values (or null specialization-entry) &optional))
  (fset:do-seq (elem (immutable-listmap-lookup (environment-specialization-environment env) from :no-error no-error))
    (when (eq to (specialization-entry-to elem))
      (return-from lookup-specialization elem)))

  (unless no-error
    (error "Unable to find specialization from ~A to ~A" from to)))

(defun lookup-specialization-by-type (env from ty &key (no-error nil))
  (declare (type environment env)
           (type symbol from)
           (type ty ty)
           (values (or null specialization-entry) &optional))
  (fset:do-seq (elem (immutable-listmap-lookup (environment-specialization-environment env) from :no-error no-error))
    (handler-case
        (progn
          (match (specialization-entry-to-ty elem) ty)
          (return-from lookup-specialization-by-type elem))
      (coalton-type-error (e)
        (declare (ignore e))))))
