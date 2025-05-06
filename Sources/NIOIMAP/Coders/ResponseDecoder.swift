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

struct ResponseDecoder: NIOSingleStepByteToMessageDecoder {
    typealias InboundOut = ResponseOrContinuationRequest

    var parser: ResponseParser

    init(
        options: ResponseParser.Options = ResponseParser.Options()
    ) {
        self.parser = ResponseParser(
            options: options
        )
    }

    mutating func decode(buffer: inout ByteBuffer) throws -> InboundOut? {
        let save = buffer
        do {
            return try self.parser.parseResponseStream(buffer: &buffer)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: save)
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> InboundOut? {
        try self.decode(buffer: &buffer)
    }
}
