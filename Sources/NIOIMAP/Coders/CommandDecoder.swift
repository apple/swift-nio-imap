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

import NIO
import NIOIMAPCore

/// Thrown if an error occurs when decoding IMAP data.
public struct IMAPDecoderError: Error {
    /// The error that was thrown by the IMAP parser.
    public var parserError: Error

    /// The bytes that were waiting to be parsed when the error was thrown.
    public var buffer: ByteBuffer
}

struct CommandDecoder: NIOSingleStepByteToMessageDecoder, IMAPMessageDecoder {
    typealias InboundOut = SynchronizedCommand

    private var parser: CommandParser

    init(literalSizeLimit: Int = IMAPDefaults.literalSizeLimit) {
        self.parser = CommandParser(literalSizeLimit: literalSizeLimit)
    }

    /// Parses out of the library's own input buffer — the path the handler takes, and the only one that
    /// delivers a large `APPEND` payload without copying it.
    mutating func decode(input: inout IMAPInputBuffer) throws -> SynchronizedCommand? {
        try self.decode(from: &input)
    }

    /// Parses out of a `ByteBuffer`, for `ByteToMessageHandler` and the decoder verifier.
    ///
    /// A `ByteBuffer` cannot vouch for its bytes, so a payload extracted on this path is copied. See
    /// `IMAPInputProcessor`.
    mutating func decode(buffer: inout ByteBuffer) throws -> SynchronizedCommand? {
        try self.decode(from: &buffer)
    }

    private mutating func decode<Input: ConsumableParserInputBuffer>(
        from input: inout Input
    ) throws -> SynchronizedCommand? {
        do {
            return try self.parser.parseCommandStream(buffer: &input)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: input.coalescedByteBuffer())
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> SynchronizedCommand? {
        try self.decode(buffer: &buffer)
    }
}
