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

    /// Parses out of the library's own input buffer — the path the handler takes.
    mutating func decode(input: inout IMAPInputBuffer) throws -> SynchronizedCommand? {
        do {
            return try self.parser.parseCommandStream(buffer: &input)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: input.coalescedByteBuffer())
        }
    }

    /// Parses out of a `ByteBuffer`, for `ByteToMessageHandler` and the decoder verifier.
    ///
    /// The parser reads only an ``IMAPInputBuffer``, so `buffer` is appended to a fresh one — kept by
    /// reference if large, copied if small — and its reader index moved past what was consumed.
    mutating func decode(buffer: inout ByteBuffer) throws -> SynchronizedCommand? {
        var input = IMAPInputBuffer()
        input.append(buffer)
        defer { buffer.moveReaderIndex(forwardBy: buffer.readableBytes - input.count) }
        return try self.decode(input: &input)
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> SynchronizedCommand? {
        try self.decode(buffer: &buffer)
    }
}
