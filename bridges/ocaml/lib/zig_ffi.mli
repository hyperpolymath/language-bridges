(* SPDX-License-Identifier: AGPL-3.0-or-later *)
(** OCaml-Zig-FFI - Core module interface

    This module provides bidirectional FFI between OCaml and Zig:
    - OCaml -> Zig: Call Zig functions from OCaml
    - Zig -> OCaml: Register OCaml callbacks for Zig to call
*)

(** {1 Library Loading} *)

(** Opaque handle to a loaded Zig library *)
type library

(** Load a Zig shared library from the given path *)
val load : string -> library

(** Close a loaded library *)
val close : library -> unit

(** {1 Version Info} *)

val version_major : int
val version_minor : int
val version_patch : int
val version_string : string

(** {1 Types} *)

module Types : sig
  open Ctypes

  val zig_int : int32 typ
  val zig_long : int64 typ
  val zig_uint : Unsigned.uint32 typ
  val zig_ulong : Unsigned.uint64 typ
  val zig_float : float typ
  val zig_double : float typ
  val zig_bool : Unsigned.uint8 typ
  val zig_size : Unsigned.size_t typ
  val zig_string : string typ
end

(** {1 Function Binding} *)

(** Get a function from the library with the given type signature *)
val get_function : library -> string -> ('a -> 'b) Ctypes.fn -> 'a -> 'b

(** {1 Result Type} *)

type 'a result =
  | Ok of 'a
  | Error of string

(** Safely call an FFI function, catching exceptions *)
val safe_call : (unit -> 'a) -> 'a result

(** {1 Example Bindings} *)

module Example : sig
  (** Add two 32-bit integers *)
  val add : library -> int32 -> int32 -> int32

  (** Multiply two 32-bit integers *)
  val multiply : library -> int32 -> int32 -> int32

  (** Calculate factorial *)
  val factorial : library -> Unsigned.uint32 -> Unsigned.uint64

  (** Calculate fibonacci number *)
  val fibonacci : library -> Unsigned.uint32 -> Unsigned.uint64

  (** Get library version as packed u32 *)
  val get_version : library -> unit -> Unsigned.uint32

  (** Get string length *)
  val string_length : library -> string -> Unsigned.size_t
end
