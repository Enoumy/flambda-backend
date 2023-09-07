(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Cmm

type irc_work_list =
  | Unknown_list
  | Precolored
  | Initial
  | Simplify
  | Freeze
  | Spill
  | Spilled
  | Coalesced
  | Colored
  | Select_stack

let string_of_irc_work_list = function
  | Unknown_list -> "unknown_list"
  | Precolored -> "precolored"
  | Initial -> "initial"
  | Simplify -> "simplify"
  | Freeze -> "freeze"
  | Spill -> "spill"
  | Spilled -> "spilled"
  | Coalesced -> "coalesced"
  | Colored -> "colored"
  | Select_stack -> "select_stack"

module V = Backend_var

module Raw_name = struct
  type t =
    | Anon
    | R
    | Var of V.t

  let create_from_var var = Var var

  let to_string t =
    match t with
    | Anon -> None
    | R -> Some "R"
    | Var var ->
      let name = V.name var in
      if String.length name <= 0 then None else Some name
end

type t =
  { mutable raw_name: Raw_name.t;
    stamp: int;
    typ: Cmm.machtype_component;
    mutable loc: location;
    mutable irc_work_list: irc_work_list;
    mutable irc_color : int option;
    mutable irc_alias : t option;
    mutable spill: bool;
    mutable part: int option;
    mutable interf: t list;
    mutable prefer: (t * int) list;
    mutable degree: int;
    mutable spill_cost: int;
    mutable visited: int }

and location =
    Unknown
  | Reg of int
  | Stack of stack_location

and stack_location =
    Local of int
  | Incoming of int
  | Outgoing of int
  | Domainstate of int

type reg = t

let dummy =
  { raw_name = Raw_name.Anon; stamp = 0; typ = Int; loc = Unknown;
    irc_work_list = Unknown_list; irc_color = None; irc_alias = None;
    spill = false; interf = []; prefer = []; degree = 0; spill_cost = 0;
    visited = 0; part = None;
  }

let currstamp = ref 0
let reg_list = ref([] : t list)
let hw_reg_list = ref ([] : t list)

let visit_generation = ref 1

(* Any visited value not equal to !visit_generation counts as "unvisited" *)
let unvisited = 0

let mark_visited r =
  r.visited <- !visit_generation

let is_visited r =
  r.visited = !visit_generation

let clear_visited_marks () =
  incr visit_generation


let create ty =
  let r = { raw_name = Raw_name.Anon; stamp = !currstamp; typ = ty;
            loc = Unknown;
            irc_work_list = Unknown_list; irc_color = None; irc_alias = None;
            spill = false; interf = []; prefer = []; degree = 0;
            spill_cost = 0; visited = unvisited; part = None; } in
  reg_list := r :: !reg_list;
  incr currstamp;
  r

let createv tyv =
  let n = Array.length tyv in
  let rv = Array.make n dummy in
  for i = 0 to n-1 do rv.(i) <- create tyv.(i) done;
  rv

let createv_like rv =
  let n = Array.length rv in
  let rv' = Array.make n dummy in
  for i = 0 to n-1 do rv'.(i) <- create rv.(i).typ done;
  rv'

let clone r =
  let nr = create r.typ in
  nr.raw_name <- r.raw_name;
  nr

let at_location ty loc =
  let r = { raw_name = Raw_name.R; stamp = !currstamp; typ = ty; loc;
            irc_work_list = Unknown_list; irc_color = None; irc_alias = None;
            spill = false; interf = []; prefer = []; degree = 0;
            spill_cost = 0; visited = unvisited; part = None; } in
  hw_reg_list := r :: !hw_reg_list;
  incr currstamp;
  r

let typv rv =
  Array.map (fun r -> r.typ) rv

let anonymous t =
  match Raw_name.to_string t.raw_name with
  | None -> true
  | Some _raw_name -> false

let is_preassigned t =
  match t.raw_name with
  | R -> true
  | Anon | Var _ -> false

let is_unknown t =
  match t.loc with
  | Unknown -> true
  | Reg _ | Stack (Local _ | Incoming _ | Outgoing _ | Domainstate _) -> false

let name t =
  match Raw_name.to_string t.raw_name with
  | None -> ""
  | Some raw_name ->
    let with_spilled =
      if t.spill then
        "spilled-" ^ raw_name
      else
        raw_name
    in
    match t.part with
    | None -> with_spilled
    | Some part -> with_spilled ^ "#" ^ Int.to_string part

let first_virtual_reg_stamp = ref (-1)

let is_stack t =
  match t.loc with
  | Stack _ -> true
  | _ -> false

let is_reg t =
  match t.loc with
  | Reg _ -> true
  | _ -> false

let size_of_contents_in_bytes t =
  match t.typ with
  | Vec128 -> Arch.size_vec128
  | Float -> Arch.size_float
  | Addr ->
    assert (Arch.size_addr = Arch.size_int);
    Arch.size_addr
  | Int | Val -> Arch.size_int

let reset() =
  (* When reset() is called for the first time, the current stamp reflects
     all hard pseudo-registers that have been allocated by Proc, so
     remember it and use it as the base stamp for allocating
     soft pseudo-registers *)
  if !first_virtual_reg_stamp = -1 then begin
    first_virtual_reg_stamp := !currstamp;
    assert (!reg_list = []) (* Only hard regs created before now *)
  end;
  currstamp := !first_virtual_reg_stamp;
  reg_list := [];
  visit_generation := 1;
  !hw_reg_list |> List.iter (fun r ->
    r.visited <- unvisited)

let all_registers() = !reg_list
let num_registers() = !currstamp

let reinit_reg r =
  r.loc <- Unknown;
  r.irc_work_list <- Unknown_list;
  r.irc_color <- None;
  r.irc_alias <- None;
  r.interf <- [];
  r.prefer <- [];
  r.degree <- 0;
  (* Preserve the very high spill costs introduced by the reloading pass *)
  if r.spill_cost >= 100000
  then r.spill_cost <- 100000
  else r.spill_cost <- 0

let reinit() =
  List.iter reinit_reg !reg_list

module RegOrder =
  struct
    type t = reg
    let compare r1 r2 = r1.stamp - r2.stamp
  end

module Set = Set.Make(RegOrder)
module Map = Map.Make(RegOrder)
module Tbl = Hashtbl.Make (struct
    type t = reg
    let equal r1 r2 = r1.stamp = r2.stamp
    let hash r = r.stamp
  end)

let add_set_array s v =
  match Array.length v with
    0 -> s
  | 1 -> Set.add v.(0) s
  | n -> let rec add_all i =
           if i >= n then s else Set.add v.(i) (add_all(i+1))
         in add_all 0

let diff_set_array s v =
  match Array.length v with
    0 -> s
  | 1 -> Set.remove v.(0) s
  | n -> let rec remove_all i =
           if i >= n then s else Set.remove v.(i) (remove_all(i+1))
         in remove_all 0

let inter_set_array s v =
  match Array.length v with
    0 -> Set.empty
  | 1 -> if Set.mem v.(0) s
         then Set.add v.(0) Set.empty
         else Set.empty
  | n -> let rec inter_all i =
           if i >= n then Set.empty
           else if Set.mem v.(i) s then Set.add v.(i) (inter_all(i+1))
           else inter_all(i+1)
         in inter_all 0

let disjoint_set_array s v =
  match Array.length v with
    0 -> true
  | 1 -> not (Set.mem v.(0) s)
  | n -> let rec disjoint_all i =
           if i >= n then true
           else if Set.mem v.(i) s then false
           else disjoint_all (i+1)
         in disjoint_all 0

let set_of_array v =
  match Array.length v with
    0 -> Set.empty
  | 1 -> Set.add v.(0) Set.empty
  | n -> let rec add_all i =
           if i >= n then Set.empty else Set.add v.(i) (add_all(i+1))
         in add_all 0

let equal_stack_location left right =
  match left, right with
  | Local left, Local right -> Int.equal left right
  | Incoming left, Incoming right -> Int.equal left right
  | Outgoing left, Outgoing right -> Int.equal left right
  | Domainstate left, Domainstate right -> Int.equal left right
  | Local _, (Incoming _ | Outgoing _ | Domainstate _)
  | Incoming _, (Local _ | Outgoing _ | Domainstate _)
  | Outgoing _, (Local _ | Incoming _ | Domainstate _)
  | Domainstate _, (Local _ | Incoming _ | Outgoing _)->
    false

let equal_location left right =
  match left, right with
  | Unknown, Unknown -> true
  | Reg left, Reg right -> Int.equal left right
  | Stack left, Stack right -> equal_stack_location left right
  | Unknown, (Reg _ | Stack _)
  | Reg _, (Unknown | Stack _)
  | Stack _, (Unknown | Reg _) ->
    false

let same_loc left right =
  (* CR-soon azewierzejew: This should also compare [reg_class] for [Stack
     (Local _)]. That's complicated because [reg_class] is definied in [Proc]
     which relies on [Reg]. *)
  equal_location left.loc right.loc

let same left right =
  Int.equal left.stamp right.stamp
