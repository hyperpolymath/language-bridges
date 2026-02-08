# zig-polyglot-extract-ffi

Zig FFI bindings for Polyglot content extraction with Idris2 ABI verification.

## Architecture

This library follows the **Hyperpolymath Universal ABI/FFI Standard**:

- **ABI (Application Binary Interface)** → **Idris2** (`src/abi/*.idr`)
  - Formal proofs of interface correctness
  - Memory layout verification
  - Platform-specific type definitions

- **FFI (Foreign Function Interface)** → **Zig** (`src/*.zig`)
  - C-compatible implementation
  - Memory-safe by default
  - Cross-platform support

## Building

```bash
zig build                         # Build debug
zig build -Doptimize=ReleaseFast  # Build optimized
zig build test                    # Run tests
```

## Usage

### From C

```c
#include "polyglot_extract.h"

int main() {
    // Use the library
    return 0;
}
```

### From Idris2

```idris
import Polyglot_Extract.ABI.Foreign

main : IO ()
main = do
  -- Use the library
  pure ()
```

### From Zig

```zig
const std = @import("std");
const lib = @import("polyglot_extract.zig");

pub fn main() !void {
    // Use the library
}
```

## Features

- ✅ Formal verification of ABI via Idris2 dependent types
- ✅ Memory-safe FFI implementation in Zig
- ✅ Cross-platform support (Linux, macOS, Windows)
- ✅ C-compatible for use from any language
- ✅ Zero runtime dependencies

## Directory Structure

```
zig-polyglot-extract-ffi/
├── src/
│   ├── abi/          # Idris2 ABI definitions
│   │   ├── Types.idr
│   │   ├── Layout.idr
│   │   └── Foreign.idr
│   └── main.zig      # Zig FFI implementation
├── build.zig
└── README.md
```

## License

AGPL-3.0-or-later

## See Also

- [Hyperpolymath RSR Standard](https://github.com/hyperpolymath/rhodium-standard-repositories)
- [Idris2 Documentation](https://idris2.readthedocs.io)
- [Zig Documentation](https://ziglang.org/documentation/master/)
