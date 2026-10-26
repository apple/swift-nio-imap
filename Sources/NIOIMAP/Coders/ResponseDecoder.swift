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

struct ResponseDecoder: NIOSingleStepByteToMessageDecoder, IMAPMessageDecoder {
    typealias InboundOut = ResponseOrContinuationRequest

    var parser: ResponseParser

    init(
        options: ResponseParser.Options = ResponseParser.Options()
    ) {
        self.parser = ResponseParser(
            options: options
        )
    }

    /// Parses out of the library's own input buffer — the path the handler takes, and the only one that
    /// delivers a large literal without copying it.
    mutating func decode(input: inout IMAPInputBuffer) throws -> InboundOut? {
        try self.decode(from: &input)
    }

    /// Parses out of a `ByteBuffer`, for `ByteToMessageHandler` and the decoder verifier.
    ///
    /// A `ByteBuffer` cannot vouch for its bytes, so a payload extracted on this path is copied. See
    /// `IMAPInputProcessor`.
    mutating func decode(buffer: inout ByteBuffer) throws -> InboundOut? {
        try self.decode(from: &buffer)
    }

    private mutating func decode<Input: ConsumableParserInputBuffer>(
        from input: inout Input
    ) throws -> InboundOut? {
        do {
            return try self.parser.parseResponseStream(buffer: &input)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: input.coalescedByteBuffer())
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> InboundOut? {
        try self.decode(buffer: &buffer)
    }
}
