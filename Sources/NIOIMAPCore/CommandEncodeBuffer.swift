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

/// Encodes IMAP client commands into wire format ready for transmission to an IMAP server.
///
/// `CommandEncodeBuffer` is the primary interface for encoding commands from the client side.
/// It handles chunking of synchronizing literals (for RFC 3501 Section 4.3 compliance) and
/// respects server capabilities when deciding which literal formats to use.
///
/// ## Usage Example
///
/// ```swift
/// var buffer = CommandEncodeBuffer(
///     options: CommandEncodingOptions(capabilities: [.literalPlus]),
///     loggingMode: false
/// )
/// buffer.writeCommand(TaggedCommand(tag: "A1", command: .login(username: "user", password: "pass")))
/// while let chunk = buffer.nextChunk() {
///     send(chunk.bytes)
///     if chunk.nextStep == .awaitContinuationRequest {
///         // Wait for the server's `+` before sending the next chunk.
///     }
/// }
/// ```
///
/// ## Where the bytes go
///
/// This is the type a client creates; it owns an ``EncoderOutputBuffer``, the sink the encoded bytes
/// are appended to, chosen once with the `sink:` argument and never named again. Leaving it out gives
/// an ``IMAPOutputBuffer``, which is the right answer unless the bytes have to land somewhere
/// specific — see ``EncoderOutputBuffer`` for the choice. The bytes come back out as an
/// ``IMAPBufferList`` from ``nextChunk()``, which converts to a `DispatchData`, to `ByteBuffer`s, or to
/// one contiguous copy.
///
/// - SeeAlso: ``ResponseEncodeBuffer``, ``CommandEncodingOptions``
public struct CommandEncodeBuffer: Hashable {
    /// The underlying buffer containing data to be written.
    ///
    /// Provides access to the raw ``EncodeBuffer`` for advanced operations,
    /// though most users should interact through the public API of `CommandEncodeBuffer`.
    @_spi(NIOIMAPInternal) public var buffer: EncodeBuffer

    /// Tracks whether we have encoded at least one catenate element.
    internal var encodedAtLeastOneCatenateElement: Bool

    /// Creates a new command encoding buffer with explicit options.
    ///
    /// - Parameters:
    ///   - sink: Where the encoded bytes are appended. Defaults to an ``IMAPOutputBuffer``, which
    ///     is the right choice unless the bytes have to land somewhere specific.
    ///   - options: The ``CommandEncodingOptions`` controlling how literals, strings,
    ///     and other protocol elements are encoded.
    ///   - encodedAtLeastOneCatenateElement: Internal tracking for CATENATE operations.
    ///     Typically `false` for new buffers.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
    public init(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        options: CommandEncodingOptions,
        encodedAtLeastOneCatenateElement: Bool = false,
        loggingMode: Bool
    ) {
        self.buffer = .clientEncodeBuffer(sink: sink, options: options, loggingMode: loggingMode)
        self.encodedAtLeastOneCatenateElement = encodedAtLeastOneCatenateElement
    }
}

// MARK: - Sendability

/// `CommandEncodeBuffer` is deliberately **not** `Sendable`, because the ``EncoderOutputBuffer`` it
/// writes into is not: see ``EncodeBuffer``. A chunk that has been handed out *is* `Sendable`.
@available(*, unavailable)
extension CommandEncodeBuffer: Sendable {}

extension CommandEncodeBuffer {
    /// The encoding options currently in use.
    ///
    /// These options determine how protocol elements are encoded (for example, whether to use
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
    /// Converts a list of ``Capability`` values into ``CommandEncodingOptions``,
    /// which automatically enables extended literal formats and binary support if the
    /// server advertises the corresponding capabilities.
    ///
    /// - Parameters:
    ///   - sink: Where the encoded bytes are appended. Defaults to an ``IMAPOutputBuffer``.
    ///   - capabilities: Server capabilities from a `CAPABILITY` response. These are
    ///     used to configure encoding options automatically.
    ///   - encodedAtLeastOneCatenateElement: Internal tracking for CATENATE operations.
    ///     Typically `false` for new buffers.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
    public init(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        capabilities: [Capability],
        encodedAtLeastOneCatenateElement: Bool = false,
        loggingMode: Bool
    ) {
        self.buffer = .clientEncodeBuffer(sink: sink, capabilities: capabilities, loggingMode: loggingMode)
        self.encodedAtLeastOneCatenateElement = encodedAtLeastOneCatenateElement
    }
}

extension CommandEncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(loggingMode: Bool = false, _ closure: (inout CommandEncodeBuffer) -> Void) -> String {
        var buffer = CommandEncodeBuffer(options: .rfc3501, loggingMode: loggingMode)
        closure(&buffer)
        var bytes: [UInt8] = []
        while let chunk = buffer.nextChunk() {
            bytes.append(contentsOf: chunk.bytes.copiedBytes())
        }
        return String(bestEffortDecodingUTF8Bytes: bytes)
    }
}

// MARK: - Chunks

extension CommandEncodeBuffer {
    /// Encoded bytes to send as one write, and what the client must do before sending more.
    public struct Chunk: Hashable, Sendable {
        /// The bytes to send, in order. Large payloads are referenced, not copied.
        public var bytes: IMAPBufferList

        /// What the client must do after sending `bytes` and before sending the next chunk.
        public var nextStep: NextStep
    }

    /// What a client does after sending a chunk.
    public enum NextStep: Hashable, Sendable {
        /// Send the next chunk right away.
        case proceed

        /// The chunk ends with a synchronizing literal header (`{n}`). Wait for the server's
        /// continuation request (`+`) before sending the next chunk.
        case awaitContinuationRequest
    }

    /// Removes and returns the next chunk of encoded bytes, ending at the first pending
    /// synchronizing literal header; returns `nil` if nothing is pending.
    ///
    /// A chunk may end with the last byte written so far, e.g. after `.append(.beginMessage(…))`:
    /// its `nextStep` is still ``NextStep/awaitContinuationRequest``, and the next chunk, once more
    /// is written, follows the `+`.
    public mutating func nextChunk() -> Chunk? {
        guard self.buffer.hasChunks || self.buffer.pendingByteCount > 0 else { return nil }
        let (chunk, end) = self.buffer.takeChunk(allowEmptyChunk: true)
        switch end {
        case .stopPoint:
            return Chunk(bytes: chunk.bytes, nextStep: .awaitContinuationRequest)
        case .pendingBytes:
            return Chunk(bytes: chunk.bytes, nextStep: .proceed)
        }
    }
}
