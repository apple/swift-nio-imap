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

public struct IMAPDecoderError: Error {
    public var parserError: Error
    public var buffer: ByteBuffer
}

struct CommandDecoder: NIOSingleStepByteToMessageDecoder {
    public typealias InboundOut = PartialCommandStream

    private var ok: ByteBuffer?
    private var parser = CommandParser()
    private var synchronisingLiteralParser = SynchronizingLiteralParser()

    public mutating func decode(buffer: inout ByteBuffer) throws -> PartialCommandStream? {
        let save = buffer
        do {
            return try self.parser.parseCommandStream(buffer: &buffer)
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: save)
        }
    }

    public mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> PartialCommandStream? {
        try self.decode(buffer: &buffer)
    }
}
