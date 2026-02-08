(* SPDX-License-Identifier: AGPL-3.0-or-later *)
(** OCaml-Zig-FFI - Core module for Zig FFI bindings

    This module provides the foundation for calling Zig libraries from OCaml.

    Architecture:
      OCaml -> Ctypes -> Zig (C ABI)

    Usage:
      {[
        open Zig_ffi

        let lib = load "./libmyzig.so"
        let result = add lib 2 3
      ]}
*)

open Ctypes
open Foreign

(** Version information *)
let version_major = 0
let version_minor = 1
let version_patch = 0
let version_string = Printf.sprintf "%d.%d.%d" version_major version_minor version_patch

(** Library handle *)
type library = {
  handle : Dl.library;
  path : string;
}

(** Load a Zig shared library from the given path *)
let load path =
  let handle = Dl.dlopen ~filename:path ~flags:[Dl.RTLD_NOW; Dl.RTLD_LOCAL] in
  { handle; path }

(** Close a loaded library *)
let close lib =
  Dl.dlclose lib.handle

(** Get a function from the library *)
let get_function lib name typ =
  foreign ~from:lib.handle name typ

(** Standard Zig FFI types *)
module Types = struct
  (** 32-bit signed integer *)
  let zig_int = int32_t

  (** 64-bit signed integer *)
  let zig_long = int64_t

  (** 32-bit unsigned integer *)
  let zig_uint = uint32_t

  (** 64-bit unsigned integer *)
  let zig_ulong = uint64_t

  (** 32-bit float *)
  let zig_float = float

  (** 64-bit float *)
  let zig_double = double

  (** Boolean (as u8) *)
  let zig_bool = uint8_t

  (** Size type *)
  let zig_size = size_t

  (** Null-terminated string *)
  let zig_string = string
end

(** Example: Create typed wrappers for common functions *)
module Example = struct
  let add lib =
    get_function lib "add" (int32_t @-> int32_t @-> returning int32_t)

  let multiply lib =
    get_function lib "multiply" (int32_t @-> int32_t @-> returning int32_t)

  let factorial lib =
    get_function lib "factorial" (uint32_t @-> returning uint64_t)

  let fibonacci lib =
    get_function lib "fibonacci" (uint32_t @-> returning uint64_t)

  let get_version lib =
    get_function lib "get_version" (void @-> returning uint32_t)

  let string_length lib =
    get_function lib "string_length" (string @-> returning size_t)
end

(** Result type for FFI operations *)
type 'a result =
  | Ok of 'a
  | Error of string

(** Safe wrapper for FFI calls *)
let safe_call f =
  try Ok (f ())
  with
  | Dl.DL_error msg -> Error ("Dynamic linking error: " ^ msg)
  | e -> Error ("FFI error: " ^ Printexc.to_string e)
