// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// decode_sensor.zig - Example: Decode a SensorReading from Bebop wire format
//
// Build:
//   cd implementations/zig && zig build
//   zig build-exe -I../implementations/zig/src examples/decode_sensor.zig
//
// Or with the library:
//   zig run examples/decode_sensor.zig --main-pkg-path implementations/zig/src

const std = @import("std");
const bridge = @import("bridge");
const abi = @import("abi");

// Re-export for convenience
const SensorReading = abi.SensorReading;
const SensorType = abi.SensorType;
const Bytes = abi.Bytes;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== Bebop-V-FFI Example: Decode SensorReading (Zig) ===\n\n", .{});

    // Check ABI version
    const version = bridge.bebop_version();
    try stdout.print("ABI Version: {d}.{d}.{d}\n\n", .{
        (version >> 16) & 0xFF,
        (version >> 8) & 0xFF,
        version & 0xFF,
    });

    // Create context
    const ctx = bridge.bebop_ctx_new() orelse {
        try stdout.print("Failed to create context\n", .{});
        return error.ContextCreationFailed;
    };
    defer bridge.bebop_ctx_free(ctx);

    // Wire format data for a SensorReading:
    // - timestamp: 2000000000 (2033-05-18 03:33:20 UTC)
    // - sensorId: "temp-001"
    // - sensorType: Temperature (1)
    // - value: 23.5
    // - unit: "C"
    // - location: "floor-1"
    // - metadata: {"status": "ok"}
    const wire_data = [_]u8{
        0x01, // field 1: timestamp
        0x00, 0x94, 0x35, 0x77, 0x00, 0x00, 0x00, 0x00, // 2000000000 LE

        0x02, // field 2: sensorId
        0x08, 0x00, 0x00, 0x00, // length = 8
        't',  'e',  'm',  'p',  '-',  '0',  '0',  '1',

        0x03, // field 3: sensorType
        0x01, 0x00, // Temperature = 1 LE

        0x04, // field 4: value
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x37, 0x40, // 23.5 as f64 LE

        0x05, // field 5: unit
        0x01, 0x00, 0x00, 0x00, // length = 1
        'C',

        0x06, // field 6: location
        0x07, 0x00, 0x00, 0x00, // length = 7
        'f',  'l',  'o',  'o',  'r',  '-',  '1',

        0x07, // field 7: metadata
        0x01, 0x00, 0x00, 0x00, // count = 1
        0x06, 0x00, 0x00, 0x00, // key length = 6
        's',  't',  'a',  't',  'u',  's',
        0x02, 0x00, 0x00, 0x00, // value length = 2
        'o',  'k',

        0x00, // end of message
    };

    try stdout.print("Wire data size: {d} bytes\n", .{wire_data.len});
    try stdout.print("Wire data (hex): ", .{});
    for (wire_data) |byte| {
        try stdout.print("{x:0>2}", .{byte});
    }
    try stdout.print("\n\n", .{});

    // Decode
    var reading = SensorReading.empty();
    const result = bridge.bebop_decode_sensor_reading(ctx, &wire_data, wire_data.len, &reading);

    if (result != @intFromEnum(abi.Error.ok)) {
        try stdout.print("Decode failed with error {d}", .{result});
        if (reading.error_message) |msg| {
            try stdout.print(": {s}", .{std.mem.span(msg)});
        }
        try stdout.print("\n", .{});
        return error.DecodeFailed;
    }

    // Print decoded data
    try stdout.print("Decoded SensorReading:\n", .{});
    try stdout.print("  timestamp: {d}\n", .{reading.timestamp});
    try printBytes(stdout, "sensor_id", reading.sensor_id);
    try stdout.print("  sensor_type: {d} ({s})\n", .{ reading.sensor_type, SensorType.name(reading.sensor_type) });
    try stdout.print("  value: {d:.2}\n", .{reading.value});
    try printBytes(stdout, "unit", reading.unit);
    try printBytes(stdout, "location", reading.location);

    try stdout.print("  metadata ({d} entries):\n", .{reading.metadata_count});
    var iter = reading.getMetadata();
    while (iter.next()) |entry| {
        try stdout.print("    \"{s}\": \"{s}\"\n", .{
            entry.key.toSlice(),
            entry.value.toSlice(),
        });
    }

    // Cleanup
    bridge.bebop_free_sensor_reading(ctx, &reading);

    try stdout.print("\nSuccess!\n", .{});
}

fn printBytes(writer: anytype, label: []const u8, bytes: Bytes) !void {
    try writer.print("  {s}: ", .{label});
    if (!bytes.isEmpty()) {
        try writer.print("\"{s}\"\n", .{bytes.toSlice()});
    } else {
        try writer.print("(empty)\n", .{});
    }
}

// Alternative standalone version that doesn't require library linking
// This demonstrates using the types directly without the FFI layer
pub fn standaloneDemo() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("=== Standalone Demo (no library linking required) ===\n\n", .{});

    // Create a reading directly
    const sensor_id = "sensor-42";
    const unit = "°C";
    const location = "lab-1";

    var reading = SensorReading{
        .timestamp = @intCast(std.time.timestamp()),
        .sensor_id = Bytes.fromSlice(sensor_id),
        .sensor_type = SensorType.temperature,
        .value = 22.7,
        .unit = Bytes.fromSlice(unit),
        .location = Bytes.fromSlice(location),
        .metadata_count = 0,
        .metadata_keys = null,
        .metadata_values = null,
        .error_code = 0,
        .error_message = null,
    };

    try stdout.print("Created SensorReading:\n", .{});
    try stdout.print("  Type: {s}\n", .{reading.sensorTypeName()});
    try stdout.print("  Value: {d:.1} {s}\n", .{ reading.value, reading.unit.toSlice() });
    try stdout.print("  Location: {s}\n", .{reading.location.toSlice()});
    try stdout.print("  Has error: {}\n", .{reading.hasError()});
}
