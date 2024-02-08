(* TEST
   * expect
*)

let apply f = f ~src_pos:Lexing.dummy_pos () ;;
[%%expect {|
val apply : (src_pos:Lexing.position -> unit -> 'a) -> 'a = <fun>
|}]

let g = fun ?src_pos:(_ = 1) () -> ()
[%%expect{|
val g : ?src_pos:int -> unit -> unit = <fun>
|}]

let _ = apply g ;;
[%%expect{|
Line 1, characters 14-15:
1 | let _ = apply g ;;
                  ^
Error: This expression has type ?src_pos:int -> unit -> unit
       but an expression was expected of type
         src_pos:Lexing.position -> (unit -> 'a)
|}]

