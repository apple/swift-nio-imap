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

public struct CommandDecoder: NIOSingleStepByteToMessageDecoder {
    public typealias InboundOut = PartialCommandStream

    private var ok: ByteBuffer?
    private var parser: CommandParser
    private var synchronisingLiteralParser = SynchronizingLiteralParser()

    public struct PartialCommandStream: Equatable {
        public var numberOfSynchronisingLiterals: Int
        public var command: CommandStream?

        internal init(numberOfSynchronisingLiterals: Int, command: CommandStream?) {
            self.numberOfSynchronisingLiterals = numberOfSynchronisingLiterals
            self.command = command
        }

        public init(_ command: CommandStream, numberOfSynchronisingLiterals: Int = 0) {
            self = .init(numberOfSynchronisingLiterals: numberOfSynchronisingLiterals, command: command)
        }

        public init(numberOfSynchronisingLiterals: Int) {
            self = .init(numberOfSynchronisingLiterals: numberOfSynchronisingLiterals, command: nil)
        }
    }

    public init(bufferLimit: Int = 1_000) {
        self.parser = CommandParser(bufferLimit: bufferLimit)
    }

    public mutating func decode(buffer: inout ByteBuffer) throws -> PartialCommandStream? {
        let save = buffer
        do {
            let framingResult = try self.synchronisingLiteralParser.parseContinuationsNecessary(buffer)

            var result = PartialCommandStream(numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount,
                                              command: nil)
            var actuallyVisible = buffer.getSlice(at: buffer.readerIndex, length: framingResult.maximumValidBytes)!
            if let command = try self.parser.parseCommandStream(buffer: &actuallyVisible) {
                // We need to discard the bytes we consumed from the real buffer.
                let consumedBytes = framingResult.maximumValidBytes - actuallyVisible.readableBytes
                buffer.moveReaderIndex(forwardBy: consumedBytes)

                assert(buffer.writerIndex == save.writerIndex,
                       "the writer index of the buffer moved whilst parsing which is not supported: \(buffer), \(save)")
                assert(consumedBytes >= 0,
                       "allegedly, we consumed a negative amount of bytes: \(consumedBytes)")
                self.synchronisingLiteralParser.consumed(consumedBytes)
                assert(consumedBytes <= framingResult.maximumValidBytes,
                       "We consumed \(consumedBytes) which is more than the framing parser thought are maximally " +
                           "valid: \(framingResult), \(self.synchronisingLiteralParser)")
                result.command = command
                return result
            } else {
                assert(framingResult.maximumValidBytes == actuallyVisible.readableBytes,
                       "parser consumed bytes on nil: readableBytes before parse: \(framingResult.maximumValidBytes), buffer: \(actuallyVisible)")
                if result.numberOfSynchronisingLiterals == 0 {
                    return nil
                } else {
                    return result
                }
            }
        } catch {
            throw IMAPDecoderError(parserError: error, buffer: save)
        }
    }

    public mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> PartialCommandStream? {
        try self.decode(buffer: &buffer)
    }
}
