# Bebop-V-FFI

> FFI bindings between Bebop binary serialization and V language for IIoT edge computing

## Project Context

This library bridges [Bebop](https://bebop.sh) (high-performance binary serialization) with [V](https://vlang.io) (systems programming language) for Industrial IoT applications. It's part of the [Kaldor IIoT](https://github.com/hyperpolymath/kaldor-iiot) ecosystem.

## Tech Stack

- **V Language** - Primary implementation language
- **C** - FFI layer and Bebop runtime
- **Bebop** - Schema definition and wire format
- **Zig** - (Planned) Stable C ABI layer for next-gen version

## Key Commands

```bash
# Build
v build -prod src/

# Test
v test tests/

# Generate bindings from schema
bebop --generator v --input schemas/*.bop --output src/

# Validate RSR compliance
just validate-rsr
```

## Architecture

```
V Application → V Bindings → C FFI → Bebop Runtime → Wire Format
```

Future (v2.0):
```
V Application → Zig FFI (C ABI) → Rust Core → Wire Format
```

## Related Projects

- [kaldor-iiot](https://github.com/hyperpolymath/kaldor-iiot) - Parent IIoT platform
- [bunsenite](https://github.com/hyperpolymath/bunsenite) - Similar FFI architecture (Nickel parser)

## Coding Standards

- Use descriptive variable names
- All public functions must have doc comments
- Zero `unsafe` blocks in public API
- Bounds checking on all buffer operations

## File Annotations

All source files must include:
```
// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
```

## RSR Compliance

- **Tier**: Bronze
- **Prohibited**: Python, TypeScript/JavaScript (use ReScript)
- **Required**: justfile, .well-known/, comprehensive docs
