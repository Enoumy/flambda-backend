# 2 "digest.mli"
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

open! Stdlib

(** MD5 message digest.

   This module provides functions to compute 128-bit 'digests' of
   arbitrary-length strings or files. The algorithm used is MD5.

   The MD5 hash function is not cryptographically secure.
   Hence, this module should not be used for security-sensitive
   applications.  More recent, stronger cryptographic primitives
   should be used instead.
*)

type t = string
(** The type of digests: 16-character strings. *)

val compare : t -> t -> int
(** The comparison function for 16-character digest, with the same
    specification as {!Stdlib.compare} and the implementation
    shared with {!String.compare}. Along with the type [t], this
    function [compare] allows the module [Digest] to be passed as
    argument to the functors {!Set.Make} and {!Map.Make}.
    @since 4.00 *)

val equal : t -> t -> bool
(** The equal function for 16-character digest.
    @since 4.03 *)

val string : string -> t
(** Return the digest of the given string. *)

val bytes : bytes -> t
(** Return the digest of the given byte sequence.
    @since 4.02 *)

val substring : string -> int -> int -> t
(** [Digest.substring s ofs len] returns the digest of the substring
   of [s] starting at index [ofs] and containing [len] characters. *)

val subbytes : bytes -> int -> int -> t
(** [Digest.subbytes s ofs len] returns the digest of the subsequence
    of [s] starting at index [ofs] and containing [len] bytes.
    @since 4.02 *)

external channel : in_channel -> int -> t = "caml_md5_chan"
(** If [len] is nonnegative, [Digest.channel ic len] reads [len]
   characters from channel [ic] and returns their digest, or raises
   [End_of_file] if end-of-file is reached before [len] characters
   are read.  If [len] is negative, [Digest.channel ic len] reads
   all characters from [ic] until end-of-file is reached and return
   their digest. *)

val file : string -> t
(** Return the digest of the file whose name is given. *)

val output : out_channel -> t -> unit
(** Write a digest on the given output channel. *)

val input : in_channel -> t
(** Read a digest from the given input channel. *)

val to_hex : t -> string
(** Return the printable hexadecimal representation of the given digest.
    @raise Invalid_argument if the argument is not exactly 16 bytes.
 *)

val from_hex : string -> t
(** Convert a hexadecimal representation back into the corresponding digest.
    @raise Invalid_argument if the argument is not exactly 32 hexadecimal
   characters.
   @since 4.00 *)
