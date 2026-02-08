# Proven Library Integration Plan

This document outlines how the [proven](https://github.com/hyperpolymath/proven) library's formally verified modules integrate with Bebop-V-FFI.

## Applicable Modules

### High Priority

| Module | Use Case | Formal Guarantee |
|--------|----------|------------------|
| `SafeFFI` | C ABI boundary safety | Correct memory ownership |
| `SafeBuffer` | Message buffer management | No overflow |
| `SafeSchema` | Bebop schema validation | Type-safe serialization |

### Medium Priority

| Module | Use Case | Formal Guarantee |
|--------|----------|------------------|
| `SafeResource` | Connection lifecycle | Valid state transitions |
| `SafeOrdering` | Message ordering | FIFO for IIoT |
| `SafeString` | String encoding | Valid UTF-8 |

## Integration Points

### 1. FFI Boundary Safety (SafeFFI)

The C ABI is the critical boundary:

```c
// bebop_v_ffi.h
typedef struct {
    uint8_t* data;      // SafeFFI.OwnedPtr
    size_t len;         // SafeFFI.BoundedSize
    uint32_t capacity;  // SafeFFI.Capacity
} BebopBuffer;
```

SafeFFI proves:
- Ownership transfer is correct (caller/callee distinction)
- Buffer bounds are respected
- Alignment requirements are met
- No use-after-free possible

### 2. Message Buffer Management (SafeBuffer)

IIoT edge devices have constrained memory:

```
incoming_message → SafeBuffer.RingBuffer → parse → dispatch
```

SafeBuffer guarantees:
- Fixed memory footprint
- Predictable latency (no malloc)
- Graceful overflow handling (oldest dropped)

### 3. Schema Validation (SafeSchema)

Bebop schemas define message structure:

```bebop
struct SensorReading {
    1 -> string device_id;
    2 -> float temperature;
    3 -> uint64 timestamp;
}
```

SafeSchema validates:
- All required fields present
- Field types match schema
- Size constraints respected

## FFI Contract Specification

The C ABI contract can be formally verified:

```idris
-- Ownership transfer proof
FFIOwnership : (buf : OwnedPtr) ->
               (transferred : TransferOwnership buf caller callee) ->
               CanFree callee buf

-- Buffer bounds proof
FFIBounds : (buf : BebopBuffer) ->
            (idx : Nat) ->
            idx < buf.len ->
            ValidAccess buf idx

-- Alignment proof
FFIAlignment : (ptr : Ptr a) ->
               aligned ptr (alignof a)
```

## IIoT-Specific Safety

For Kaldor IIoT integration:

| Constraint | proven Module | Guarantee |
|------------|---------------|-----------|
| Memory-constrained | SafeBuffer.RingBuffer | Fixed footprint |
| Real-time | SafeBuffer (no malloc) | Predictable latency |
| Unreliable network | SafeOrdering | Message ordering |
| Low power | SafeResource | Clean lifecycle |

## Implementation Layer Mapping

| Layer | Implementation | proven Verification |
|-------|----------------|---------------------|
| Zig impl | `implementations/zig` | SafeFFI proofs |
| Rust impl | `implementations/rust` | SafeFFI proofs |
| V bindings | `v/bebop_bridge.v` | SafeSchema validation |
| C ABI | `include/bebop_v_ffi.h` | Contract specification |

## Edge Computing Guarantees

For ESP32-C6 and RISC-V microcontrollers:

```idris
-- Memory bounds for constrained devices
EdgeMemory : (device : Device) ->
             (msg : Message) ->
             sizeof msg <= device.maxMessageSize

-- Real-time deadline
EdgeRealTime : (deadline : Time) ->
               (process : Message -> IO Response) ->
               WCET process < deadline
```

## Status

- [ ] Add SafeFFI for C ABI verification
- [ ] Implement SafeBuffer for ring buffer
- [ ] Integrate SafeSchema for Bebop schemas
- [ ] Generate contract proofs for bebop_v_ffi.h
