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

/// A wrapper around ``EncodeBuffer`` for encoding IMAP commands.
///
/// `CommandEncodeBuffer` is the primary interface for encoding client commands into
/// wire format ready for transmission to an IMAP server. It wraps an ``EncodeBuffer``
/// configured in client mode and provides command-specific encoding operations.
///
/// ## Usage Example
///
/// ```swift
/// var buffer = CommandEncodeBuffer(
///     buffer: ByteBuffer(),
///     options: CommandEncodingOptions(capabilities: [.literalPlus]),
///     loggingMode: false
/// )
/// // Encode command data into buffer
/// // Retrieve chunks via buffer.buffer.nextChunk()
/// ```
///
/// - SeeAlso: ``EncodeBuffer``, ``ResponseEncodeBuffer``, ``CommandEncodingOptions``
public struct CommandEncodeBuffer: Hashable, Sendable {
    /// The underlying buffer containing data to be written.
    ///
    /// This provides access to the raw ``EncodeBuffer`` for advanced operations,
    /// though most users should interact through the public API of `CommandEncodeBuffer`.
    @_spi(NIOIMAPInternal) public var buffer: EncodeBuffer

    /// Tracks whether we have encoded at least one catenate element.
    internal var encodedAtLeastOneCatenateElement: Bool

    /// Creates a new command encoding buffer with explicit options.
    ///
    /// - Parameters:
    ///   - buffer: The initial `ByteBuffer` to build upon. This buffer is copied,
    ///     not taken as inout.
    ///   - options: The ``CommandEncodingOptions`` controlling how literals, strings,
    ///     and other protocol elements are encoded.
    ///   - encodedAtLeastOneCatenateElement: Internal tracking for CATENATE operations.
    ///     Typically `false` for new buffers.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
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
    /// The encoding options currently in use.
    ///
    /// These options determine how protocol elements are encoded (e.g., whether to use
    /// quoted strings, which literal formats are supported). You can modify these
    /// options at runtime to change encoding behavior for subsequent write operations.
    ///
    /// - Note: Changing this property affects all subsequent encoding operations in
    ///   this buffer.
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

    /// Creates a new command encoding buffer from server capabilities.
    ///
    /// This initializer converts a list of ``Capability`` values into ``CommandEncodingOptions``,
    /// which automatically enables extended literal formats and binary support if the
    /// server advertises the corresponding capabilities.
    ///
    /// - Parameters:
    ///   - buffer: The initial `ByteBuffer` to build upon. This buffer is copied,
    ///     not taken as inout.
    ///   - capabilities: Server capabilities from a `CAPABILITY` response. These are
    ///     used to configure encoding options automatically.
    ///   - encodedAtLeastOneCatenateElement: Internal tracking for CATENATE operations.
    ///     Typically `false` for new buffers.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
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
