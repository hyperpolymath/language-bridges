-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Callback Example: Demonstrates bidirectional FFI with callbacks

with Ada.Text_IO;
with Interfaces.C;
with Zig_FFI;

procedure Callback_Example is
   use Ada.Text_IO;
   use Interfaces.C;

   -- Callback procedure that will be called from Zig
   procedure My_Int_Handler (Value : int)
      with Convention => C;

   procedure My_Int_Handler (Value : int) is
   begin
      Put_Line ("  [Ada callback received] Value:" & Value'Image);
   end My_Int_Handler;

   -- Iterator callback that returns control signal
   function My_Iterator_Handler (Value : int) return int
      with Convention => C;

   function My_Iterator_Handler (Value : int) return int is
   begin
      Put_Line ("  [Iterator] Processing:" & Value'Image);
      -- Return 0 to continue, non-zero to stop
      if Value >= 5 then
         Put_Line ("  [Iterator] Stopping at 5");
         return 1;  -- Stop iteration
      end if;
      return 0;  -- Continue
   end My_Iterator_Handler;

begin
   Put_Line ("=== Ada-Zig-FFI Callback Example ===");
   Put_Line ("");

   -- Register and invoke int callback
   Put_Line ("--- Int Callback Demo ---");
   Zig_FFI.Register_Int_Callback (My_Int_Handler'Access);
   Put_Line ("Invoking callback with value 42:");
   Zig_FFI.Invoke_Int_Callback (42);
   Put_Line ("Invoking callback with value -100:");
   Zig_FFI.Invoke_Int_Callback (-100);
   Put_Line ("");

   -- Iterator pattern demonstration
   Put_Line ("--- Iterator Pattern Demo ---");
   Put_Line ("Iterating from 1 to 10 with step 1 (stopping at 5):");
   declare
      Count : constant int := Zig_FFI.For_Each_In_Range
        (Start   => 1,
         Stop    => 10,
         Step    => 1,
         Handler => My_Iterator_Handler'Access);
   begin
      Put_Line ("Iterations completed:" & Count'Image);
   end;
   Put_Line ("");

   Put_Line ("=== Example Complete ===");
end Callback_Example;
