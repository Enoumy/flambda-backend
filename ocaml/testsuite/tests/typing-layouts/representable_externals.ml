(* TEST
   flags = "-extension layouts"
   * native
   * bytecode
*)


external[@rep_poly] id : ('a : any). 'a -> 'a = "%identity"

type t_any : any
module N = Stdlib__Nativeint_u
module I32 = Stdlib__Int32_u
module I64 = Stdlib__Int64_u
module F = Stdlib__Float_u
let () =
   (* id (assert false : t_any); *)
  Printf.printf "%s\n" (N.to_string (id #1n));
  Printf.printf "%s\n" (I32.to_string (id #2l));
  Printf.printf "%s\n" (I64.to_string (id #3L));
  Printf.printf "%s\n" (F.to_string (id #4.));
  Printf.printf "%s\n" (id "abcde");
  ()

let () = Printf.printf "%s %f\n" (id "abc") (F.to_float (id #1.))
