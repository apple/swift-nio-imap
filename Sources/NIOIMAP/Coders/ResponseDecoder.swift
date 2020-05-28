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

public struct ResponseDecoder: NIOSingleStepByteToMessageDecoder {
    public typealias InboundOut = ResponseOrContinueRequest

    var parser: ResponseParser

    public init(bufferLimit: Int = 1_000, expectGreeting: Bool = true) {
        self.parser = ResponseParser(bufferLimit: bufferLimit, expectGreeting: expectGreeting)
    }

    public mutating func decode(buffer: inout ByteBuffer) throws -> ResponseOrContinueRequest? {
        let save = buffer
        do {
            return try self.parser.parseResponseStream(buffer: &buffer)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: save)
        }
    }

    public mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> ResponseOrContinueRequest? {
        try self.decode(buffer: &buffer)
    }
}
