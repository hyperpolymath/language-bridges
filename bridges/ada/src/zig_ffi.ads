-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Ada-Zig-FFI - Core package for Zig FFI bindings
--
-- This package provides the foundation for calling Zig libraries from Ada.
--
-- Architecture:
--   Ada -> Interfaces.C -> Zig (C ABI)
--
-- Usage:
--   with Zig_FFI;
--   Result : Interfaces.C.int := Zig_FFI.Add (2, 3);

with Interfaces.C;
with System;
use Interfaces.C;

package Zig_FFI is

   -- Version information
   Version_Major : constant := 0;
   Version_Minor : constant := 1;
   Version_Patch : constant := 0;

   -- Get library version as packed integer
   function Get_Version return unsigned
      with Import => True,
           Convention => C,
           External_Name => "get_version";

   -- Basic arithmetic operations
   function Add (A, B : int) return int
      with Import => True,
           Convention => C,
           External_Name => "add";

   function Multiply (A, B : int) return int
      with Import => True,
           Convention => C,
           External_Name => "multiply";

   -- Mathematical functions
   function Factorial (N : unsigned) return unsigned_long
      with Import => True,
           Convention => C,
           External_Name => "factorial";

   function Fibonacci (N : unsigned) return unsigned_long
      with Import => True,
           Convention => C,
           External_Name => "fibonacci";

   -- String operations
   function String_Length (Str : char_array) return size_t
      with Import => True,
           Convention => C,
           External_Name => "string_length";

   -- Buffer operations
   function Buffer_Sum (Ptr : System.Address; Len : size_t) return unsigned_long
      with Import => True,
           Convention => C,
           External_Name => "buffer_sum";

   -- ==========================================================================
   -- CALLBACK TYPES (Zig -> Ada)
   -- ==========================================================================

   -- Callback procedure types for bidirectional FFI
   type Int_Procedure is access procedure (Value : int)
      with Convention => C;

   type Long_Procedure is access procedure (Value : long)
      with Convention => C;

   type Status_Callback is access procedure (Code : int; Message : char_array)
      with Convention => C;

   type Int_Handler is access function (Value : int) return int
      with Convention => C;

   type Error_Callback is access procedure (Message : char_array)
      with Convention => C;

   type Bounds_Error_Callback is access procedure (Index : size_t; Length : size_t)
      with Convention => C;

   -- ==========================================================================
   -- CALLBACK REGISTRATION (Ada -> Zig)
   -- ==========================================================================

   procedure Register_Int_Callback (Cb : Int_Procedure)
      with Import => True,
           Convention => C,
           External_Name => "register_int_callback";

   procedure Register_Long_Callback (Cb : Long_Procedure)
      with Import => True,
           Convention => C,
           External_Name => "register_long_callback";

   procedure Register_Status_Callback (Cb : Status_Callback)
      with Import => True,
           Convention => C,
           External_Name => "register_status_callback";

   -- ==========================================================================
   -- CALLBACK INVOCATION (Trigger Zig to call Ada)
   -- ==========================================================================

   procedure Invoke_Int_Callback (Value : int)
      with Import => True,
           Convention => C,
           External_Name => "invoke_int_callback";

   procedure Invoke_Long_Callback (Value : long)
      with Import => True,
           Convention => C,
           External_Name => "invoke_long_callback";

   procedure Invoke_Status_Callback (Code : int; Message : char_array)
      with Import => True,
           Convention => C,
           External_Name => "invoke_status_callback";

   -- ==========================================================================
   -- ITERATOR PATTERN
   -- ==========================================================================

   -- Iterate over a range with Ada-style control
   -- Handler returns 0 to continue, non-zero to stop
   function For_Each_In_Range
     (Start   : int;
      Stop    : int;
      Step    : int;
      Handler : Int_Handler) return int
      with Import => True,
           Convention => C,
           External_Name => "for_each_in_range";

   -- ==========================================================================
   -- SAFETY-CRITICAL PATTERNS
   -- ==========================================================================

   -- Safe division with error callback on division by zero
   -- Returns 0 on success, -1 on error
   function Safe_Divide
     (Numerator   : int;
      Denominator : int;
      Result      : access int;
      Error_Cb    : Error_Callback) return int
      with Import => True,
           Convention => C,
           External_Name => "safe_divide";

   -- Bounds-checked array access with error callback on violation
   -- Returns 0 on success, -1 on bounds error
   function Checked_Array_Access
     (Arr          : System.Address;
      Len          : size_t;
      Index        : size_t;
      Result       : access int;
      Bounds_Error : Bounds_Error_Callback) return int
      with Import => True,
           Convention => C,
           External_Name => "checked_array_access";

private
   -- Internal implementation details

end Zig_FFI;
