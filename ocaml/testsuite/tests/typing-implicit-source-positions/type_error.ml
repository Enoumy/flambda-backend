(* TEST
   * expect
*)

type (_, _) refl = Refl : ('a, 'a) refl
let apply (_ : unit -> 'a) : 'a = assert false
let go (type a) (Refl : (unit, a) refl) = apply (fun () : a -> ())

[%%expect{|
type (_, _) refl = Refl : ('a, 'a) refl
val apply : (unit -> 'a) -> 'a = <fun>
Line 3, characters 42-66:
3 | let go (type a) (Refl : (unit, a) refl) = apply (fun () : a -> ())
                                              ^^^^^^^^^^^^^^^^^^^^^^^^
Error: This expression has type a = unit
       but an expression was expected of type 'a
       This instance of unit is ambiguous:
       it would escape the scope of its equation
|}]
