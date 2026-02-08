// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Example.swift - Example usage of Swift-Zig FFI
//
// To run this example:
//   1. Build the library: zig build
//   2. Create an Xcode project
//   3. Add libswift_zig_ffi.a and SwiftZigFFI.swift
//   4. Set SwiftZigFFI.h as bridging header
//   5. Add this code to your app

import Foundation

/// Example demonstrating Swift-Zig FFI capabilities
func runSwiftZigFFIDemo() {
    print("=== Swift-Zig FFI Demo ===\n")

    // 1. Version Check
    print("1. Version Check")
    let version = zigLibraryVersion
    print("   Library version: \(version.major).\(version.minor).\(version.patch)")
    print()

    // 2. Context Creation
    print("2. Context Creation")
    do {
        let context = try ZigContext()
        print("   ✓ Context created successfully")

        // 3. Data Transformation
        print("\n3. Data Transformation")
        let input = ZigBytes("hello world from swift!")
        let output = try transformData(context: context, input: input)
        if let result = String(data: output, encoding: .utf8) {
            print("   Input:  \"hello world from swift!\"")
            print("   Output: \"\(result)\"")
        }

        // 4. Progress Callbacks
        print("\n4. Progress Callbacks (Swift → Zig)")
        let largeData = ZigBytes(String(repeating: "x", count: 10000))
        var progressUpdates = 0

        processData(
            context: context,
            input: largeData,
            progress: { current, total in
                progressUpdates += 1
                // Only print every 25%
                if current == total || current % (total / 4) == 0 {
                    let percent = (current * 100) / total
                    print("   Progress: \(percent)%")
                }
                return true // Continue processing
            },
            completion: { result in
                if result.isSuccess {
                    print("   ✓ Processing complete (\(progressUpdates) updates)")
                } else {
                    print("   ✗ Error: \(result.error!)")
                }
            }
        )

        // 5. Event Callbacks (Zig → Swift)
        print("\n5. Event Callbacks (Zig → Swift)")
        var eventsReceived = 0

        registerEventHandler { eventType, data in
            eventsReceived += 1
            print("   Event received: type=\(eventType), bytes=\(data.count)")
        }
        print("   ✓ Event handler registered")

        // Trigger an event from Zig side (for testing)
        szf_invoke_event(42, szf_bytes_empty())
        print("   Events received: \(eventsReceived)")

        // Unregister
        registerEventHandler(nil)
        print("   ✓ Event handler unregistered")

        // 6. Error Callbacks
        print("\n6. Error Callbacks (Zig → Swift)")
        var errorsReceived = 0

        registerErrorHandler { code, message in
            errorsReceived += 1
            print("   Error received: code=\(code), message=\(message ?? "nil")")
        }
        print("   ✓ Error handler registered")

        // Trigger an error from Zig side (for testing)
        szf_invoke_error(-1, "test error")
        print("   Errors received: \(errorsReceived)")

        registerErrorHandler(nil)
        print("   ✓ Error handler unregistered")

        // 7. Context Reset
        print("\n7. Context Reset")
        context.reset()
        print("   ✓ Context arena reset (memory freed for reuse)")

        print("\n=== Demo Complete ===")

    } catch {
        print("   ✗ Error: \(error)")
    }
}

/// Example: Cancellable operation
func cancellableOperationDemo() {
    print("\n=== Cancellable Operation Demo ===\n")

    do {
        let context = try ZigContext()
        let data = ZigBytes(String(repeating: "y", count: 50000))
        var cancelled = false

        processData(
            context: context,
            input: data,
            progress: { current, total in
                let percent = (current * 100) / total
                print("Progress: \(percent)%")

                // Cancel at 50%
                if percent >= 50 && !cancelled {
                    print("Cancelling...")
                    cancelled = true
                    return false // Stop processing
                }
                return true
            },
            completion: { result in
                if result.isSuccess {
                    print("Completed (shouldn't happen if cancelled)")
                } else if case .callbackFailed = result.error {
                    print("✓ Operation cancelled as expected")
                } else {
                    print("Error: \(result.error!)")
                }
            }
        )

    } catch {
        print("Error: \(error)")
    }
}

/// Example: Error handling
func errorHandlingDemo() {
    print("\n=== Error Handling Demo ===\n")

    do {
        let context = try ZigContext()

        // Try to transform empty data
        let emptyInput = ZigBytes(Data())
        let output = try transformData(context: context, input: emptyInput)
        print("Empty input result: \(output.count) bytes")

    } catch let error as ZigError {
        print("Caught ZigError: \(error)")
    } catch {
        print("Caught error: \(error)")
    }
}

// Uncomment to run demos:
// runSwiftZigFFIDemo()
// cancellableOperationDemo()
// errorHandlingDemo()
