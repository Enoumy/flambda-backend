[@@@ocaml.warning "+a-4-30-40-41-42"]

open Cfg_regalloc_utils

val irc_debug : bool

val irc_verbose : bool

val irc_invariants : bool

val log : indent:int -> ('a, Format.formatter, unit) format -> 'a

val log_body_and_terminator :
  indent:int ->
  Cfg.basic_instruction_list ->
  Cfg.terminator Cfg.instruction ->
  liveness ->
  unit

module Color : sig
  type t = int
end

module RegisterStamp : sig
  type t = int

  type pair

  val pair : t -> t -> pair

  val fst : pair -> t

  val snd : pair -> t

  module PairSet : sig
    type t

    val make : num_registers:int -> t

    val clear : t -> unit

    val mem : t -> pair -> bool

    val add : t -> pair -> unit

    val cardinal : t -> int

    val iter : t -> f:(pair -> unit) -> unit
  end
end

module Degree : sig
  type t = int

  val infinite : t

  val to_string : t -> string

  val to_float : t -> float
end

val is_move_instruction : Instruction.t -> bool

val all_precolored_regs : Reg.t array

val k : Reg.t -> int

val update_register_locations : unit -> unit

module Split_mode : sig
  type t =
    | Off
    | Naive

  val all : t list

  val to_string : t -> string

  val env : t Lazy.t
end

module Spilling_heuristics : sig
  type t =
    | Set_choose
    | Flat_uses
    | Hierarchical_uses

  val all : t list

  val to_string : t -> string

  val env : t Lazy.t
end
