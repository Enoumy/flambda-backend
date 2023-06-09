(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                   Fabrice Le Fessant, INRIA Saclay                     *)
(*                                                                        *)
(*   Copyright 2012 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Misc

type pers_flags =
  | Rectypes
  | Alerts of alerts
  | Opaque
  | Unsafe_string

type kind =
  | Normal of { cmi_impl : Compilation_unit.t }
  | Parameter

type cmi_infos = {
    cmi_name : Compilation_unit.Name.t;
    cmi_kind : kind;
    cmi_sign : Types.signature_item list;
    cmi_secondary_sign : Types.signature_item list option;
    cmi_params : Global.Name.t list;
    cmi_arg_for : Global.Name.t option;
    cmi_crcs : Import_info.Intf.t array;
    cmi_flags : pers_flags list;
}

(* write the magic + the cmi information *)
val output_cmi : string -> out_channel -> cmi_infos -> Digest.t

(* read the cmi information (the magic is supposed to have already been read) *)
val input_cmi : in_channel -> cmi_infos

(* read a cmi from a filename, checking the magic *)
val read_cmi : string -> cmi_infos

(* Error report *)

type error =
  | Not_an_interface of filepath
  | Wrong_version_interface of filepath * string
  | Corrupted_interface of filepath

exception Error of error

open Format

val report_error: formatter -> error -> unit
