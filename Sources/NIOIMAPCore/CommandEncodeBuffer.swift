//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// Used to buffer commands before writing to the network.
public struct CommandEncodeBuffer: Hashable, Sendable {
    /// The underlying buffer containing data to be written.
    @_spi(NIOIMAPInternal) public var buffer: EncodeBuffer

    /// Tracks whether we have encoded at least one catenate element.
    internal var encodedAtLeastOneCatenateElement: Bool

    /// Creates a new `CommandEncodeBuffer` from a given initial `ByteBuffer` and configuration options.
    /// - parameter buffer: The initial `ByteBuffer` to build upon.
    /// - parameter options: The options to use when writing commands and data.
    public init(
        buffer: ByteBuffer,
        options: CommandEncodingOptions,
        encodedAtLeastOneCatenateElement: Bool = false,
        loggingMode: Bool
    ) {
        self.buffer = .clientEncodeBuffer(buffer: buffer, options: options, loggingMode: loggingMode)
        self.encodedAtLeastOneCatenateElement = encodedAtLeastOneCatenateElement
    }
}

extension CommandEncodeBuffer {
    /// The options used when writing commands and data.
    public var options: CommandEncodingOptions {
        get {
            guard case .client(let options) = buffer.mode else {
                preconditionFailure("Command encoder mode must be 'client'.")
            }
            return options
        }
        set {
            buffer.mode = .client(options: newValue)
        }
    }

    /// Creates a new `CommandEncodeBuffer` from a given initial `ByteBuffer` and configuration options.
    /// - parameter buffer: The initial `ByteBuffer` to build upon.
    /// - parameter capabilities: Capabilities to use when writing commands and data. Will be converted to `CommandEncodingOptions`.
    public init(
        buffer: ByteBuffer,
        capabilities: [Capability],
        encodedAtLeastOneCatenateElement: Bool = false,
        loggingMode: Bool
    ) {
        self.buffer = .clientEncodeBuffer(buffer: buffer, capabilities: capabilities, loggingMode: loggingMode)
        self.encodedAtLeastOneCatenateElement = encodedAtLeastOneCatenateElement
    }
}

extension CommandEncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(loggingMode: Bool = false, _ closure: (inout CommandEncodeBuffer) -> Void) -> String {
        var buffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .rfc3501, loggingMode: loggingMode)
        closure(&buffer)
        var chunk = buffer.buffer.nextChunk()
        var result = String(bestEffortDecodingUTF8Bytes: chunk.bytes.readableBytesView)
        while chunk.waitForContinuation {
            chunk = buffer.buffer.nextChunk()
            result += String(bestEffortDecodingUTF8Bytes: chunk.bytes.readableBytesView)
        }
        return result
    }
}
