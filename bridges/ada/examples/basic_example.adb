-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Basic Example: Demonstrates calling Zig functions from Ada

with Ada.Text_IO;
with Interfaces.C;
with Zig_FFI;

procedure Basic_Example is
   use Ada.Text_IO;
   use Interfaces.C;
begin
   Put_Line ("=== Ada-Zig-FFI Basic Example ===");
   Put_Line ("");

   -- Version information
   declare
      Version : constant unsigned := Zig_FFI.Get_Version;
      Major   : constant unsigned := Version / 2**16;
      Minor   : constant unsigned := (Version / 2**8) mod 2**8;
      Patch   : constant unsigned := Version mod 2**8;
   begin
      Put_Line ("Library Version:" &
                Major'Image & "." &
                Minor'Image & "." &
                Patch'Image);
   end;
   Put_Line ("");

   -- Arithmetic operations
   Put_Line ("--- Arithmetic Operations ---");
   Put_Line ("Add (5, 3) =" & Zig_FFI.Add (5, 3)'Image);
   Put_Line ("Multiply (7, 6) =" & Zig_FFI.Multiply (7, 6)'Image);
   Put_Line ("");

   -- Mathematical functions
   Put_Line ("--- Mathematical Functions ---");
   Put_Line ("Factorial (5) =" & Zig_FFI.Factorial (5)'Image);
   Put_Line ("Factorial (10) =" & Zig_FFI.Factorial (10)'Image);
   Put_Line ("Fibonacci (10) =" & Zig_FFI.Fibonacci (10)'Image);
   Put_Line ("Fibonacci (20) =" & Zig_FFI.Fibonacci (20)'Image);
   Put_Line ("");

   -- String operations
   Put_Line ("--- String Operations ---");
   declare
      Test_String : constant char_array := To_C ("Hello, Ada-Zig-FFI!");
   begin
      Put_Line ("String_Length (""Hello, Ada-Zig-FFI!"") =" &
                Zig_FFI.String_Length (Test_String)'Image);
   end;
   Put_Line ("");

   Put_Line ("=== Example Complete ===");
end Basic_Example;
