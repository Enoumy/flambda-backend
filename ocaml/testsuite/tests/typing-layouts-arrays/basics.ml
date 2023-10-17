(* TEST
   * flambda2
   ** expect
     flags = "-extension layouts_alpha"
   ** expect
     flags = "-extension layouts_beta"
*)

(*******************************************)
(* Test 1: Support unboxed types in arrays *)

type t_any : any

type t1 = float# array
type t2 = int32# array
type t3 = int64# array
type t4 = nativeint# array
type t5 = t_any array

type ('a : float64) t1' = 'a array
type ('a : bits32) t2' = 'a array
type ('a : bits64) t3' = 'a array
type ('a : word) t4' = 'a array
type ('a : any) t5' = 'a array

[%%expect{|
type t_any : any
type t1 = float# array
type t2 = int32# array
type t3 = int64# array
type t4 = nativeint# array
type t5 = t_any array
type ('a : float64) t1' = 'a array
type ('a : bits32) t2' = 'a array
type ('a : bits64) t3' = 'a array
type ('a : word) t4' = 'a array
type ('a : any) t5' = 'a array
|}];;

(*****************************)
(* Test 2: array expressions *)

let v1 = [| #1. |]
[%%expect{|
val v1 : float# array = [|<abstr>|]
|}];;


let v2 = [| #1l |]
[%%expect{|
val v2 : int32# array = [|<abstr>|]
|}];;


let v3 = [| #1L |]
[%%expect{|
val v3 : int64# array = [|<abstr>|]
|}];;


let v4 = [| #1n |]
[%%expect{|
val v4 : nativeint# array = [|<abstr>|]
|}];;

(****************************************)
(* Test 3: Array operations do not work *)

let f (x : float# array) = x.(0)
[%%expect{|
Line 1, characters 27-28:
1 | let f (x : float# array) = x.(0)
                               ^
Error: This expression has type float# array
       but an expression was expected of type 'a array
       The layout of float# is float64, because
         it is the primitive float64 type float#.
       But the layout of float# must be a sublayout of value, because
         of layout requirements from an imported definition.
|}];;

let f (x : float# array) = Array.length x
[%%expect{|
Line 1, characters 40-41:
1 | let f (x : float# array) = Array.length x
                                            ^
Error: This expression has type float# array
       but an expression was expected of type 'a array
       The layout of float# is float64, because
         it is the primitive float64 type float#.
       But the layout of float# must be a sublayout of value, because
         of layout requirements from an imported definition.
|}];;

(*****************************************************************)
(* Test 4: Calling wrong primitives on unboxed array kinds fails *)

external get : float# array -> int -> float = "%floatarray_safe_get"
let d (x : float# array) = get x 0

[%%expect{|
external get : float# array -> int -> float = "%floatarray_safe_get"
Line 2, characters 27-34:
2 | let d (x : float# array) = get x 0
                               ^^^^^^^
Error: Array kind unboxed_float can only be operated on using its own primitives
       and those primitives can only work on unboxed_float
|}];;


(* Doesn't prevent the use of [Obj.magic] *)
external get : floatarray -> int -> float = "%floatarray_safe_get"
let d (x : float# array) = get (Obj.magic x : floatarray) 0

[%%expect{|
external get : floatarray -> int -> float = "%floatarray_safe_get"
val d : float# array -> float = <fun>
|}];;

external get : ('a : any). 'a array -> int -> float = "%floatarray_safe_get"
let d (x : 'a array) = get x 0

[%%expect{|
external get : ('a : any). 'a array -> int -> float = "%floatarray_safe_get"
Line 2, characters 23-30:
2 | let d (x : 'a array) = get x 0
                           ^^^^^^^
Error: A representable layout is required here.
|}];;

external get : int32# array -> int -> float = "%floatarray_safe_get"
let d (x : int32# array) = get x 0

[%%expect{|
external get : int32# array -> int -> float = "%floatarray_safe_get"
Line 2, characters 27-34:
2 | let d (x : int32# array) = get x 0
                               ^^^^^^^
Error: Array kind unboxed_int32 can only be operated on using its own primitives
       and those primitives can only work on unboxed_int32
|}];;

external get : int64# array -> int -> float = "%floatarray_safe_get"
let d (x : int64# array) = get x 0

[%%expect{|
external get : int64# array -> int -> float = "%floatarray_safe_get"
Line 2, characters 27-34:
2 | let d (x : int64# array) = get x 0
                               ^^^^^^^
Error: Array kind unboxed_int64 can only be operated on using its own primitives
       and those primitives can only work on unboxed_int64
|}];;

external get : nativeint# array -> int -> float = "%floatarray_safe_get"
let d (x : nativeint# array) = get x 0

[%%expect{|
external get : nativeint# array -> int -> float = "%floatarray_safe_get"
Line 2, characters 31-38:
2 | let d (x : nativeint# array) = get x 0
                                   ^^^^^^^
Error: Array kind unboxed_nativeint can only be operated on using its own primitives
       and those primitives can only work on unboxed_nativeint
|}];;
