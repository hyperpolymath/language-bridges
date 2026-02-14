<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md -- Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-14 -->

# TOPOLOGY -- language-bridges

## System Architecture

```
language-bridges/
├── .machine_readable/    # RSR state files
├── .github/workflows/    # CI/CD
├── contractiles/         # RSR contractile agreements
├── bridges/              # Zig FFI bridge implementations
│   ├── ada/              # Ada <-> Zig bridge
│   ├── ats2/             # ATS2 <-> Zig bridge
│   ├── bebop-v/          # Bebop/V <-> Zig bridge
│   ├── c/                # C <-> Zig bridge
│   ├── gleam/            # Gleam <-> Zig bridge
│   ├── idris2/           # Idris2 <-> Zig bridge
│   ├── ocaml/            # OCaml <-> Zig bridge
│   ├── polyglot/         # Multi-language bridge
│   ├── rust/             # Rust <-> Zig bridge
│   └── swift/            # Swift <-> Zig bridge
├── README.adoc           # Overview
└── justfile              # Task runner
```

## Completion Dashboard

| Component | Status | Progress |
|-----------|--------|----------|
| RSR Structure | Active | `████████░░` 80% |
| Ada Bridge | Active | `██████░░░░` 60% |
| ATS2 Bridge | Active | `██████░░░░` 60% |
| Bebop/V Bridge | Active | `██████░░░░` 60% |
| C Bridge | Active | `██████░░░░` 60% |
| Gleam Bridge | Active | `██████░░░░` 60% |
| Idris2 Bridge | Active | `██████░░░░` 60% |
| OCaml Bridge | Active | `██████░░░░` 60% |
| Polyglot Bridge | Active | `████░░░░░░` 40% |
| Rust Bridge | Active | `██████░░░░` 60% |
| Swift Bridge | Active | `██████░░░░` 60% |
| Documentation | Active | `██████░░░░` 60% |

## Key Dependencies

- RSR Template: `rsr-template-repo`
- Build tool: Zig compiler (C ABI compatibility layer)
- Follows Idris2 ABI + Zig FFI standard
