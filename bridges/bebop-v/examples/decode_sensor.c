// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
//
// decode_sensor.c - Example: Decode a SensorReading from Bebop wire format
//
// Compile (after building libmain.so):
//   gcc -o decode_sensor decode_sensor.c -L../implementations/zig/zig-out/lib -lmain -Wl,-rpath,'$ORIGIN/../implementations/zig/zig-out/lib'
//
// Or with static linking:
//   gcc -o decode_sensor decode_sensor.c ../implementations/zig/zig-out/lib/libmain.a

#include <stdio.h>
#include <string.h>
#include "../include/bebop_v_ffi.h"

// Helper to print VBytes as string
static void print_vbytes(const char* label, VBytes b) {
    printf("  %s: ", label);
    if (b.ptr && b.len > 0) {
        printf("\"%.*s\"\n", (int)b.len, b.ptr);
    } else {
        printf("(empty)\n");
    }
}

// Helper to get sensor type name
static const char* sensor_type_name(uint16_t type) {
    switch (type) {
        case SENSOR_TYPE_TEMPERATURE: return "Temperature";
        case SENSOR_TYPE_HUMIDITY:    return "Humidity";
        case SENSOR_TYPE_PRESSURE:    return "Pressure";
        case SENSOR_TYPE_VIBRATION:   return "Vibration";
        default:                      return "Unknown";
    }
}

int main(void) {
    printf("=== Bebop-V-FFI Example: Decode SensorReading ===\n\n");

    // Check ABI version
    uint32_t version = bebop_version();
    printf("ABI Version: %d.%d.%d\n\n",
           (version >> 16) & 0xFF,
           (version >> 8) & 0xFF,
           version & 0xFF);

    // Create context
    BebopCtx* ctx = bebop_ctx_new();
    if (!ctx) {
        fprintf(stderr, "Failed to create context\n");
        return 1;
    }

    // Wire format data for a SensorReading:
    // - timestamp: 2000000000 (2033-05-18 03:33:20 UTC)
    // - sensorId: "temp-001"
    // - sensorType: Temperature (1)
    // - value: 23.5
    // - unit: "C"
    // - location: "floor-1"
    // - metadata: {"status": "ok"}
    const uint8_t wire_data[] = {
        0x01,  // field 1: timestamp
        0x00, 0x94, 0x35, 0x77, 0x00, 0x00, 0x00, 0x00,  // 2000000000 LE

        0x02,  // field 2: sensorId
        0x08, 0x00, 0x00, 0x00,  // length = 8
        't', 'e', 'm', 'p', '-', '0', '0', '1',

        0x03,  // field 3: sensorType
        0x01, 0x00,  // Temperature = 1 LE

        0x04,  // field 4: value
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x37, 0x40,  // 23.5 as f64 LE

        0x05,  // field 5: unit
        0x01, 0x00, 0x00, 0x00,  // length = 1
        'C',

        0x06,  // field 6: location
        0x07, 0x00, 0x00, 0x00,  // length = 7
        'f', 'l', 'o', 'o', 'r', '-', '1',

        0x07,  // field 7: metadata
        0x01, 0x00, 0x00, 0x00,  // count = 1
        0x06, 0x00, 0x00, 0x00,  // key length = 6
        's', 't', 'a', 't', 'u', 's',
        0x02, 0x00, 0x00, 0x00,  // value length = 2
        'o', 'k',

        0x00  // end of message
    };

    printf("Wire data size: %zu bytes\n", sizeof(wire_data));
    printf("Wire data (hex): ");
    for (size_t i = 0; i < sizeof(wire_data); i++) {
        printf("%02x", wire_data[i]);
    }
    printf("\n\n");

    // Decode
    VSensorReading reading = {0};
    int32_t result = bebop_decode_sensor_reading(ctx, wire_data, sizeof(wire_data), &reading);

    if (result != BEBOP_OK) {
        fprintf(stderr, "Decode failed with error %d", result);
        if (reading.error_message) {
            fprintf(stderr, ": %s", reading.error_message);
        }
        fprintf(stderr, "\n");
        bebop_ctx_free(ctx);
        return 1;
    }

    // Print decoded data
    printf("Decoded SensorReading:\n");
    printf("  timestamp: %lu\n", (unsigned long)reading.timestamp);
    print_vbytes("sensor_id", reading.sensor_id);
    printf("  sensor_type: %u (%s)\n", reading.sensor_type, sensor_type_name(reading.sensor_type));
    printf("  value: %.2f\n", reading.value);
    print_vbytes("unit", reading.unit);
    print_vbytes("location", reading.location);

    printf("  metadata (%zu entries):\n", reading.metadata_count);
    for (size_t i = 0; i < reading.metadata_count; i++) {
        VBytes key = reading.metadata_keys[i];
        VBytes val = reading.metadata_values[i];
        printf("    \"%.*s\": \"%.*s\"\n",
               (int)key.len, key.ptr,
               (int)val.len, val.ptr);
    }

    // Cleanup
    bebop_free_sensor_reading(ctx, &reading);
    bebop_ctx_free(ctx);

    printf("\nSuccess!\n");
    return 0;
}
