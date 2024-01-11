(* TEST
   * expect
   flags = "-extension layouts"
   * expect
   flags = "-extension layouts_beta"
*)

module F = Stdlib__Float_u

type t_any : any
external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"

let f () = id (assert false : t_any)
[%%expect{|
module F = Stdlib__Float_u
type t_any : any
external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
Line 6, characters 14-36:
6 | let f () = id (assert false : t_any)
                  ^^^^^^^^^^^^^^^^^^^^^^
Error: This expression has type t_any but an expression was expected of type
         ('a : '_representable_layout_1)
       The layout of t_any is any, because
         of the definition of t_any at line 3, characters 0-16.
       But the layout of t_any must be representable, because
         it's the type of an expression in a structure.
|}]

type ('a : any) t
external[@rep_poly] id : ('a : any). 'a t -> 'a t = "%identity"
let f () = id (assert false : t_any t)
[%%expect{|
type ('a : any) t
external id : ('a : any). 'a t -> 'a t = "%identity" [@@repr_poly]
Line 3, characters 14-38:
3 | let f () = id (assert false : t_any t)
                  ^^^^^^^^^^^^^^^^^^^^^^^^
Error: This expression has type t_any t
       but an expression was expected of type 'a t
       The layout of t_any is any, because
         of the definition of t_any at line 3, characters 0-16.
       But the layout of t_any must be representable, because
         it's the type of an expression in a structure.
|}]


external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
(* This works *)
let () = Format.printf "%f %s\n" (F.to_float (id #1.)) (id "abc"); Format.print_flush ()
[%%expect{|
external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
1.000000 abc
|}]

module M = struct
  let id' x = id x
  (* But not this *)
  let () = Format.printf "%f %s\n" (F.to_float (id' #1.)) (id' "abc")
end
[%%expect{|
Line 4, characters 63-68:
4 |   let () = Format.printf "%f %s\n" (F.to_float (id' #1.)) (id' "abc")
                                                                   ^^^^^
Error: This expression has type string but an expression was expected of type
         ('a : float64)
       The layout of string is value, because
         it is the primitive value type string.
       But the layout of string must be a sublayout of float64, because
         of the definition of id' at line 2, characters 10-18.
|}]

(********************)
(* Module inclusion *)

(* External in both *)
module S : sig
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end = struct
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end

[%%expect{|
module S :
  sig external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly] end
|}]

module S : sig
  external id : ('a : any). 'a -> 'a = "%identity"
end = struct
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end

[%%expect{|
Lines 3-5, characters 6-3:
3 | ......struct
4 |   external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
5 | end
Error: Signature mismatch:
       Modules do not match:
         sig
           external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
         end
       is not included in
         sig external id : 'a -> 'a = "%identity" end
       Values do not match:
         external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
       is not included in
         external id : 'a -> 'a = "%identity"
       The two primitives have different [@repr_poly] attributes
|}]

module S : sig
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end = struct
  external id : ('a : any). 'a -> 'a = "%identity"
end

[%%expect{|
Lines 3-5, characters 6-3:
3 | ......struct
4 |   external id : ('a : any). 'a -> 'a = "%identity"
5 | end
Error: Signature mismatch:
       Modules do not match:
         sig external id : 'a -> 'a = "%identity" end
       is not included in
         sig
           external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
         end
       Values do not match:
         external id : 'a -> 'a = "%identity"
       is not included in
         external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
       The two primitives have different [@repr_poly] attributes
|}]

(* External in struct *)

module S : sig
  val id : ('a : float64). 'a -> 'a
end = struct
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end

let () = Format.printf "%f\n" (F.to_float (S.id #1.)); Format.print_flush ()

[%%expect{|
module S : sig val id : ('a : float64). 'a -> 'a end
1.000000
|}]

let () = Format.printf "%s\n" (S.id "abc")

[%%expect{|
Line 1, characters 36-41:
1 | let () = Format.printf "%s\n" (S.id "abc")
                                        ^^^^^
Error: This expression has type string but an expression was expected of type
         ('a : float64)
       The layout of string is value, because
         it is the primitive value type string.
       But the layout of string must be a sublayout of float64, because
         of the definition of id at line 2, characters 2-35.
|}]


module S : sig
  val id : ('a : any). 'a -> 'a
end = struct
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end

[%%expect{|
Lines 3-5, characters 6-3:
3 | ......struct
4 |   external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
5 | end
Error: Signature mismatch:
       Modules do not match:
         sig
           external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
         end
       is not included in
         sig val id : ('a : any). 'a -> 'a end
       Values do not match:
         external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
       is not included in
         val id : ('a : any). 'a -> 'a
       The type 'a -> 'a is not compatible with the type 'b -> 'b
       The layout of 'a is any, because
         of the definition of id at line 2, characters 2-31.
       But the layout of 'a must be representable, because
         it's the type of an expression in a structure.
|}]


(* External in sig *)
module S : sig
  external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"
end = struct
  let id: ('a : any). 'a -> 'a = assert false
end

[%%expect{|
Lines 3-5, characters 6-3:
3 | ......struct
4 |   let id: ('a : any). 'a -> 'a = assert false
5 | end
Error: Signature mismatch:
       Modules do not match:
         sig val id : ('a : any). 'a -> 'a end
       is not included in
         sig
           external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
         end
       Values do not match:
         val id : ('a : any). 'a -> 'a
       is not included in
         external id : ('a : any). 'a -> 'a = "%identity" [@@repr_poly]
       The implementation is not a primitive.
|}]

(********************)
(* Variable capture *)

let f (type a : any) () =
  let module M = struct
    external[@rep_poly] id : ('a : any). 'a -> a -> 'a = "%apply"
  end in
  M

[%%expect{|
Line 3, characters 47-48:
3 |     external[@rep_poly] id : ('a : any). 'a -> a -> 'a = "%apply"
                                                   ^
Error: External types must have a representable layout.
       The layout of a is any, because
         of the annotation on the abstract type declaration for a.
       But the layout of a must be representable, because
         it's the type of an argument in an external declaration.
|}]
