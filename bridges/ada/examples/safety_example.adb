-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Safety Example: Demonstrates safety-critical patterns with error handling

with Ada.Text_IO;
with Interfaces.C;
with System;
with Zig_FFI;

procedure Safety_Example is
   use Ada.Text_IO;
   use Interfaces.C;

   -- Error callback for division by zero
   procedure Division_Error_Handler (Message : char_array)
      with Convention => C;

   procedure Division_Error_Handler (Message : char_array) is
   begin
      Put_Line ("  [ERROR] Division error: " & To_Ada (Message));
   end Division_Error_Handler;

   -- Bounds error callback for array access violations
   procedure Bounds_Error_Handler (Index : size_t; Length : size_t)
      with Convention => C;

   procedure Bounds_Error_Handler (Index : size_t; Length : size_t) is
   begin
      Put_Line ("  [ERROR] Bounds violation: index" &
                Index'Image & " >= length" & Length'Image);
   end Bounds_Error_Handler;

begin
   Put_Line ("=== Ada-Zig-FFI Safety Example ===");
   Put_Line ("");

   -- Safe division demonstration
   Put_Line ("--- Safe Division Demo ---");
   declare
      Result : aliased int;
      Status : int;
   begin
      -- Successful division
      Put_Line ("Safe_Divide (100, 4):");
      Status := Zig_FFI.Safe_Divide
        (Numerator   => 100,
         Denominator => 4,
         Result      => Result'Access,
         Error_Cb    => null);
      if Status = 0 then
         Put_Line ("  Result:" & Result'Image);
      end if;

      -- Division by zero with error callback
      Put_Line ("Safe_Divide (50, 0) - with error callback:");
      Status := Zig_FFI.Safe_Divide
        (Numerator   => 50,
         Denominator => 0,
         Result      => Result'Access,
         Error_Cb    => Division_Error_Handler'Access);
      if Status /= 0 then
         Put_Line ("  Operation failed (as expected)");
      end if;
   end;
   Put_Line ("");

   -- Bounds-checked array access demonstration
   Put_Line ("--- Bounds-Checked Array Access Demo ---");
   declare
      type Int_Array is array (0 .. 4) of aliased int
         with Convention => C;

      Data   : Int_Array := (10, 20, 30, 40, 50);
      Result : aliased int;
      Status : int;
   begin
      -- Successful access
      Put_Line ("Accessing Data (3) - valid index:");
      Status := Zig_FFI.Checked_Array_Access
        (Arr          => Data (0)'Address,
         Len          => Data'Length,
         Index        => 3,
         Result       => Result'Access,
         Bounds_Error => null);
      if Status = 0 then
         Put_Line ("  Value at index 3:" & Result'Image);
      end if;

      -- Out of bounds access with error callback
      Put_Line ("Accessing Data (10) - invalid index:");
      Status := Zig_FFI.Checked_Array_Access
        (Arr          => Data (0)'Address,
         Len          => Data'Length,
         Index        => 10,
         Result       => Result'Access,
         Bounds_Error => Bounds_Error_Handler'Access);
      if Status /= 0 then
         Put_Line ("  Access failed (as expected)");
      end if;
   end;
   Put_Line ("");

   -- Buffer sum demonstration
   Put_Line ("--- Buffer Sum Demo ---");
   declare
      type Byte_Array is array (0 .. 4) of aliased Interfaces.C.unsigned_char
         with Convention => C;

      Data : Byte_Array := (1, 2, 3, 4, 5);
      Sum  : unsigned_long;
   begin
      Sum := Zig_FFI.Buffer_Sum (Data (0)'Address, Data'Length);
      Put_Line ("Buffer_Sum ([1, 2, 3, 4, 5]) =" & Sum'Image);
   end;
   Put_Line ("");

   Put_Line ("=== Example Complete ===");
end Safety_Example;
