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
import NIOIMAPCore

/// Something that parses one message at a time out of an ``IMAPInputBuffer``.
///
/// This is the same contract as `NIOSingleStepByteToMessageDecoder`, over the library's own input
/// buffer rather than over a `ByteBuffer`: return a message and consume its bytes, or return `nil` and
/// consume nothing because not enough has arrived.
internal protocol IMAPMessageDecoder {
    /// What one call produces.
    associatedtype InboundOut

    /// Parses the next message, consuming its bytes from `input`.
    ///
    /// - Parameter input: The bytes received so far.
    /// - Returns: The next message, or `nil` if more bytes are needed.
    mutating func decode(input: inout IMAPInputBuffer) throws -> InboundOut?
}

/// Accumulates received bytes and drives a decoder over them.
///
/// This is what `NIOSingleStepByteToMessageProcessor` does, over an ``IMAPInputBuffer`` instead of a
/// `ByteBuffer` — and the difference is the whole reason it exists. NIO's processor appends every read
/// into one contiguous buffer and moves the unparsed remainder to the front between reads, so a message
/// that arrives in two reads is copied in order to be parsed, and the parser only ever sees one region.
/// This keeps each read where it landed and parses across the boundary instead: nothing but a small read
/// is copied when bytes arrive, and a large literal can be handed to the caller as a reference to the
/// received bytes rather than as a copy of them, which only an ``IMAPInputBuffer`` can offer.
///
/// A `final class` rather than a struct so that a handler can hold it in a `let` and call it without
/// taking exclusive access to itself for the duration — the same shape, and the same re-entrancy
/// behaviour, as the NIO type it replaces.
internal final class IMAPInputProcessor<Decoder: IMAPMessageDecoder> {
    private var decoder: Decoder

    /// The bytes received and not yet parsed.
    private var input = IMAPInputBuffer()

    /// How many unparsed bytes may pile up before the connection is rejected, if there is a limit.
    private let maximumBufferSize: Int?

    /// The error that ended decoding, if one has. Once set, the stream is unusable: the bytes that
    /// caused it would only fail again, and keeping them would let a peer grow the buffer without
    /// bound while every read re-parsed — and, for the error, re-copied — all of it.
    private var failure: Error?

    /// How many bytes are waiting to be parsed.
    internal var bufferedByteCount: Int { self.input.count }

    /// How many messages in a row the decoder may return without consuming a byte.
    ///
    /// Some messages consume nothing, but the parsers' state machines bound how many come in a row: on
    /// the command side two (`.append(.messageBytes)` with no bytes, then `.append(.endMessage)`, for a
    /// `{0}` literal; likewise `.catenateData` for a zero-length `TEXT`), on the response side one
    /// (`.fetch(.streamingEnd)`). The step after each always consumes. Twice the longest chain leaves
    /// room for one more without letting a stalled decoder spin the event loop on a single read.
    static var maximumMessagesWithoutProgress: Int { 4 }

    /// Creates a processor.
    ///
    /// - Parameters:
    ///   - decoder: What to parse with.
    ///   - maximumBufferSize: The most bytes that may wait to be parsed. Checked once the decoder has
    ///     stopped producing messages, so a message larger than this is what trips it, not a read that
    ///     happens to be large.
    internal init(_ decoder: Decoder, maximumBufferSize: Int? = nil) {
        self.decoder = decoder
        self.maximumBufferSize = maximumBufferSize
    }

    /// Adds a read and parses everything that has become parseable.
    ///
    /// - Parameters:
    ///   - buffer: The bytes that just arrived. Retained if at least 1 KiB, copied otherwise.
    ///   - messageReceiver: Called once per message, in order.
    /// - Throws: Whatever the decoder throws, `ByteToMessageDecoderError.PayloadTooLargeError` if more
    ///   than `maximumBufferSize` bytes are waiting once it stops producing messages, or an
    ///   ``IMAPDecoderError`` carrying ``NoForwardProgress`` if it keeps producing messages without
    ///   consuming (see ``maximumMessagesWithoutProgress``). Each is final: the buffered bytes are
    ///   dropped and every later call throws the same error without decoding. (`ByteToMessageHandler`
    ///   also stops decoding, but reports later reads as
    ///   `ByteToMessageDecoderError.dataReceivedInErrorState`.) What `messageReceiver` throws is
    ///   passed through and is not final.
    internal func process(buffer: ByteBuffer, _ messageReceiver: (Decoder.InboundOut) throws -> Void) throws {
        if let failure = self.failure { throw failure }
        self.input.append(buffer)
        var messagesWithoutProgress = 0
        while true {
            // Measured around `decode` alone: `messageReceiver` may re-enter and append a read.
            let unparsed = self.input.count
            guard let message = try self.decodeNext() else { break }
            messagesWithoutProgress = self.input.count < unparsed ? 0 : messagesWithoutProgress + 1
            guard messagesWithoutProgress <= Self.maximumMessagesWithoutProgress else {
                throw self.fail(
                    IMAPDecoderError(parserError: NoForwardProgress(), buffer: self.input.coalescedByteBuffer())
                )
            }
            try messageReceiver(message)
        }
        if let maximumBufferSize = self.maximumBufferSize, self.input.count > maximumBufferSize {
            throw self.fail(ByteToMessageDecoderError.PayloadTooLargeError())
        }
    }

    /// The next message, or `nil` if more bytes are needed or a re-entrant call has already failed.
    private func decodeNext() throws -> Decoder.InboundOut? {
        guard self.failure == nil else { return nil }
        do {
            return try self.decoder.decode(input: &self.input)
        } catch {
            throw self.fail(error)
        }
    }

    /// Records `error` as final and drops the buffered bytes.
    private func fail(_ error: Error) -> Error {
        self.failure = error
        self.input.removeAll()
        return error
    }
}

extension ParserInputBuffer {
    /// The bytes waiting to be parsed, coalesced into one `ByteBuffer`.
    ///
    /// This copies, so it is for the error path only — an ``IMAPDecoderError`` carries the bytes the
    /// parser choked on, and that is worth a copy of a frame that is about to close the connection.
    internal func coalescedByteBuffer() -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(count)
        for region in byteRegions {
            region.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Void in
                buffer.writeBytes(bytes)
            }
        }
        return buffer
    }
}
