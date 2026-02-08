// SPDX-License-Identifier: AGPL-3.0-or-later
//
// SwiftZigFFI.swift - Swift wrapper for Zig library
//
// Provides idiomatic Swift API over the C ABI bridge.
// Uses the auto-generated SwiftZigFFI.h bridging header.

import Foundation

// MARK: - Error Types

/// Errors from the Zig library
public enum ZigError: Error, CustomStringConvertible {
    case nullPointer
    case invalidUTF8
    case allocationFailed
    case invalidLength
    case notFound
    case alreadyExists
    case callbackFailed
    case notImplemented
    case unknown(code: Int32, message: String?)

    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer"
        case .invalidUTF8: return "Invalid UTF-8"
        case .allocationFailed: return "Allocation failed"
        case .invalidLength: return "Invalid length"
        case .notFound: return "Not found"
        case .alreadyExists: return "Already exists"
        case .callbackFailed: return "Callback failed"
        case .notImplemented: return "Not implemented"
        case .unknown(let code, let message):
            return message ?? "Unknown error (code: \(code))"
        }
    }

    static func from(code: Int32, message: UnsafePointer<CChar>? = nil) -> ZigError {
        let msg = message.map { String(cString: $0) }
        switch code {
        case SZF_ERR_NULL_PTR: return .nullPointer
        case SZF_ERR_INVALID_UTF8: return .invalidUTF8
        case SZF_ERR_ALLOC_FAILED: return .allocationFailed
        case SZF_ERR_INVALID_LENGTH: return .invalidLength
        case SZF_ERR_NOT_FOUND: return .notFound
        case SZF_ERR_ALREADY_EXISTS: return .alreadyExists
        case SZF_ERR_CALLBACK_FAILED: return .callbackFailed
        case SZF_ERR_NOT_IMPLEMENTED: return .notImplemented
        default: return .unknown(code: code, message: msg)
        }
    }
}

// MARK: - Context

/// Manages Zig library context and memory
public final class ZigContext {
    private var ctx: OpaquePointer?

    public init() throws {
        ctx = szf_context_new()
        guard ctx != nil else {
            throw ZigError.allocationFailed
        }
    }

    deinit {
        if let ctx = ctx {
            szf_context_free(ctx)
        }
    }

    /// Reset context for reuse (invalidates previous allocations)
    public func reset() {
        szf_context_reset(ctx)
    }

    /// Get last error message
    public var lastError: String? {
        guard let msg = szf_context_get_error(ctx) else { return nil }
        return String(cString: msg)
    }

    internal var pointer: OpaquePointer? { ctx }
}

// MARK: - Data Types

/// Swift wrapper for SzfBytes
public struct ZigBytes {
    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public init(_ string: String) {
        self.data = Data(string.utf8)
    }

    /// Convert to SzfBytes for C ABI (pointer valid only during closure)
    internal func withCBytes<T>(_ body: (SzfBytes) -> T) -> T {
        data.withUnsafeBytes { buffer in
            let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
            let bytes = SzfBytes(ptr: ptr, len: buffer.count, cap: 0, owned: 0)
            return body(bytes)
        }
    }
}

/// Swift wrapper for SzfResult
public struct ZigResult {
    public let isSuccess: Bool
    public let error: ZigError?
    public let data: Data?

    internal init(from result: SzfResult) {
        self.isSuccess = result.code == SZF_OK
        if isSuccess {
            if let ptr = result.data.ptr, result.data.len > 0 {
                self.data = Data(bytes: ptr, count: result.data.len)
            } else {
                self.data = nil
            }
            self.error = nil
        } else {
            self.data = nil
            self.error = ZigError.from(code: result.code, message: result.message)
        }
    }
}

// MARK: - Callbacks

/// Progress callback closure type
public typealias ProgressHandler = (_ current: Int, _ total: Int) -> Bool

/// Result callback closure type
public typealias ResultHandler = (ZigResult) -> Void

/// Event callback closure type
public typealias EventHandler = (_ eventType: Int32, _ data: Data) -> Void

/// Error callback closure type
public typealias ErrorHandler = (_ code: Int32, _ message: String?) -> Void

// Callback context storage (prevent ARC release during callback)
private var globalEventHandler: EventHandler?
private var globalErrorHandler: ErrorHandler?

// MARK: - Callback Registration

/// Register global event handler (Zig → Swift notifications)
public func registerEventHandler(_ handler: EventHandler?) {
    globalEventHandler = handler

    if handler != nil {
        szf_register_event_callback({ eventType, data, _ in
            let swiftData: Data
            if let ptr = data.ptr, data.len > 0 {
                swiftData = Data(bytes: ptr, count: data.len)
            } else {
                swiftData = Data()
            }
            globalEventHandler?(eventType, swiftData)
        }, nil)
    } else {
        szf_register_event_callback(nil, nil)
    }
}

/// Register global error handler (Zig → Swift error notifications)
public func registerErrorHandler(_ handler: ErrorHandler?) {
    globalErrorHandler = handler

    if handler != nil {
        szf_register_error_callback({ code, message, _ in
            let msg = message.map { String(cString: $0) }
            globalErrorHandler?(code, msg)
        }, nil)
    } else {
        szf_register_error_callback(nil, nil)
    }
}

// MARK: - Operations

/// Process data with progress and result callbacks
public func processData(
    context: ZigContext,
    input: ZigBytes,
    progress: ProgressHandler? = nil,
    completion: @escaping ResultHandler
) {
    // Store closures in context to prevent release
    class CallbackContext {
        var progress: ProgressHandler?
        var completion: ResultHandler?
    }

    let callbackCtx = CallbackContext()
    callbackCtx.progress = progress
    callbackCtx.completion = completion

    let ctxPtr = Unmanaged.passRetained(callbackCtx).toOpaque()

    let progressCb: SzfProgressCallback? = progress != nil ? { current, total, ctx in
        guard let ctx = ctx else { return true }
        let callbackCtx = Unmanaged<CallbackContext>.fromOpaque(ctx).takeUnretainedValue()
        return callbackCtx.progress?(Int(current), Int(total)) ?? true
    } : nil

    let resultCb: SzfResultCallback = { result, ctx in
        guard let ctx = ctx else { return }
        let callbackCtx = Unmanaged<CallbackContext>.fromOpaque(ctx).takeRetainedValue()
        callbackCtx.completion?(ZigResult(from: result))
    }

    input.withCBytes { bytes in
        _ = szf_process_data(
            context.pointer,
            bytes,
            progressCb,
            ctxPtr,
            resultCb,
            ctxPtr
        )
    }
}

/// Transform data (example: uppercase)
public func transformData(context: ZigContext, input: ZigBytes) throws -> Data {
    var output = SzfBytes()

    let result = input.withCBytes { bytes in
        szf_transform_data(context.pointer, bytes, &output)
    }

    guard result == SZF_OK else {
        throw ZigError.from(code: result, message: szf_context_get_error(context.pointer))
    }

    guard let ptr = output.ptr, output.len > 0 else {
        return Data()
    }

    return Data(bytes: ptr, count: output.len)
}

// MARK: - Version

/// Get library version
public var zigLibraryVersion: (major: Int, minor: Int, patch: Int) {
    let ver = szf_version()
    return (
        major: Int((ver >> 16) & 0xFF),
        minor: Int((ver >> 8) & 0xFF),
        patch: Int(ver & 0xFF)
    )
}

/// Get library version string
public var zigLibraryVersionString: String {
    let v = zigLibraryVersion
    return "\(v.major).\(v.minor).\(v.patch)"
}
