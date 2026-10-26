//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOIMAP

/// Drivers that encode server responses the way `IMAPServerHandler` does.
public enum ResponseEncoding {
    /// Encodes `responses` through a single long-lived buffer, draining after each one.
    ///
    /// This is what `IMAPServerHandler` does: it holds one `ResponseEncodeBuffer` for the lifetime
    /// of the connection and calls `readBytes()` once per response. `readBytes()` hands the bytes out
    /// and then clears, which releases the sink's storage — so this driver is where the per-response
    /// allocation that costs shows up.
    ///
    /// - Parameters:
    ///   - responses: The responses to encode, in order.
    ///   - options: The encoding options.
    ///   - sink: Called with the bytes of each response.
    /// - Returns: The total number of bytes encoded.
    @discardableResult
    public static func encodeReusingBuffer(
        _ responses: [Response],
        options: ResponseEncodingOptions = ResponseEncodingOptions(),
        sink: (IMAPBufferList) -> Void
    ) -> Int {
        var encodeBuffer = ResponseEncodeBuffer(options: options, loggingMode: false)
        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            let bytes = encodeBuffer.readBytes()
            byteCount += bytes.byteCount
            sink(bytes)
        }
        return byteCount
    }

    /// Encodes `responses` through a fresh buffer per response.
    ///
    /// The counterpart to ``encodeReusingBuffer(_:options:sink:)``: it pays an allocation per
    /// response too, but a different one. Having both means the cost of buffer *reuse* is
    /// attributable rather than folded into the cost of encoding.
    ///
    /// - Parameters:
    ///   - responses: The responses to encode, in order.
    ///   - options: The encoding options.
    ///   - sink: Called with the bytes of each response.
    /// - Returns: The total number of bytes encoded.
    @discardableResult
    public static func encodeWithFreshBuffer(
        _ responses: [Response],
        options: ResponseEncodingOptions = ResponseEncodingOptions(),
        sink: (IMAPBufferList) -> Void
    ) -> Int {
        var byteCount = 0
        for response in responses {
            var encodeBuffer = ResponseEncodeBuffer(options: options, loggingMode: false)
            encodeBuffer.writeResponse(response)
            let bytes = encodeBuffer.readBytes()
            byteCount += bytes.byteCount
            sink(bytes)
        }
        return byteCount
    }
}

// MARK: - The handler's shape

extension ResponseEncoding {
    /// Encodes `responses` through one long-lived buffer the way `IMAPServerHandler` writes them: one
    /// `ByteBuffer` per region, with no coalescing.
    ///
    /// The counterpart to ``encodeReusingBuffer(_:options:sink:)`` for measuring the *hand-out*: what a
    /// region costs on its way to a channel is nothing when the sink wrote into a `ByteBuffer`, and one
    /// copy when it wrote into its own segments. Paired across ``OutputBufferKind``.
    ///
    /// - Parameters:
    ///   - responses: The responses to encode, in order.
    ///   - options: The encoding options.
    ///   - output: Which sink to encode into.
    ///   - write: Called with each buffer, in order, as a channel write would be.
    /// - Returns: The total number of bytes encoded.
    @discardableResult
    public static func encodeAsHandler(
        _ responses: [Response],
        options: ResponseEncodingOptions = ResponseEncodingOptions(),
        output: OutputBufferKind,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var encodeBuffer: ResponseEncodeBuffer
        switch output {
        case .segments:
            encodeBuffer = ResponseEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
        case .byteBuffer:
            encodeBuffer = ResponseEncodeBuffer(sink: ByteBufferOutput(), options: options, loggingMode: false)
        }

        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            byteCount += encodeBuffer.readBytes().writeAsHandler(write)
        }
        return byteCount
    }
}
