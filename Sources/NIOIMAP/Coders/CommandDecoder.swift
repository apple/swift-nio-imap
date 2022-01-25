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

    /// The buffer that was provided to the parser.
    public var buffer: ByteBuffer
}

struct CommandDecoder: NIOSingleStepByteToMessageDecoder {
    typealias InboundOut = SynchronizedCommand

    private var ok: ByteBuffer?
    private var parser: CommandParser
    private var synchronisingLiteralParser = SynchronizingLiteralParser()

    init(literalSizeLimit: Int = IMAPDefaults.literalSizeLimit) {
        self.parser = CommandParser(literalSizeLimit: literalSizeLimit)
    }

    mutating func decode(buffer: inout ByteBuffer) throws -> SynchronizedCommand? {
        let save = buffer
        do {
            return try self.parser.parseCommandStream(buffer: &buffer)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: save)
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> SynchronizedCommand? {
        try self.decode(buffer: &buffer)
    }
}
