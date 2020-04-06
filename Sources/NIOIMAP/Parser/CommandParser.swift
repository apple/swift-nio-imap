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

extension NIOIMAP {

    public struct CommandParser: Parser {

        enum Mode: Equatable {
            case lines
            case idle
            case streamingAppend(Int)
        }

        let bufferLimit: Int
        private(set) var mode: Mode = .lines
        private var framingParser: IMAPFramingParser

        public init(bufferLimit: Int = 1_000) {
            self.bufferLimit = bufferLimit
            self.framingParser = IMAPFramingParser(bufferSizeLimit: bufferLimit)
        }
        
        /// Parses a given `ByteBuffer` into a `CommandStream` that may then be transmitted.
        /// Parsing depends on the current mode of the parser.
        /// - parameter buffer: A `ByteBuffer` that will be consumed for parsing.
        /// - returns: A `CommandStream` that can be sent.
        public mutating func parseCommandStream(buffer overallBuffer: inout ByteBuffer) throws -> NIOIMAP.CommandStream? {
            let framingResult = try self.framingParser.parse(&overallBuffer)
            // TODO: We need to hand back `framingResult.numberOfContinuationRequestsToSend` to make sure we actually
            // send that number of continuations :).

            if var line = framingResult.line {
                let command = try self.parsePreFramedLine(&line)
                if line.readableBytes != 0 {
                    // There are left-overs after parsing a pre-framed line. This can only mean we're streaming, or
                    // some bug of course.
                    assert(command.isStreamingCommand,
                           """
                           BUG in the SwiftNIO IMAP Parser (please report): We received the IMAP frame \
                           '\(String(decoding: framingResult.line!.readableBytesView, as: Unicode.UTF8.self))' which \
                           should parse into exactly IMAP command unless it's a command we stream. The parsed \
                           command \(command) however isn't marked as a streaming response.
                           """)

                    // ok, let's unparse the left-overs
                    overallBuffer.moveReaderIndex(to: overallBuffer.readerIndex - line.readableBytes)
                    // let's make sure we unparsed the right stuff.
                    assert(overallBuffer.readableBytesView.starts(with: line.readableBytesView))
                }
                return command
            } else {
                return nil
            }
        }

        private mutating func parsePreFramedLine(_ lineBuffer: inout ByteBuffer) throws -> NIOIMAP.CommandStream {
            switch self.mode {
            case .streamingAppend(let remaining):
                let bytes = self.parseBytes(buffer: &lineBuffer, remaining: remaining)
                try GrammarParser.parseCommandEnd(buffer: &lineBuffer, tracker: .new)
                return .bytes(bytes)
            case .idle:
                try GrammarParser.parseIdleDone(buffer: &lineBuffer, tracker: .new)
                self.mode = .lines
                return .idleDone
            case .lines:
                let command = try self.parseCommand(buffer: &lineBuffer)
                if case .append(to: _, firstMessageMetadata: let firstMetdata) = command.type {
                    self.mode = .streamingAppend(firstMetdata.data.byteCount)
                } else {
                    try GrammarParser.parseCommandEnd(buffer: &lineBuffer, tracker: .new)
                }
                if case .idleStart = command.type {
                    self.mode = .idle
                }
                return .command(command)
            }
        }
        
        /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
        /// only those that are required will be extracted. If not enough bytes are provided then the given
        /// `ByteBuffer` will be emptied.
        /// - parameter buffer: The buffer from which bytes should be extracted.
        /// - returns: A new `ByteBuffer` containing extracted bytes.
        internal mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> ByteBuffer {
            if buffer.readableBytes >= remaining {
                let bytes = buffer.readSlice(length: remaining)!
                self.mode = .lines
                return bytes
            }
            
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            self.mode = .streamingAppend(remaining - bytes.readableBytes)
            return bytes
        }

        /// Attempts to parse a given `ByteBuffer` into a `ClientCommand`
        /// Note that the `ByteBuffer` argument is consumable. If parsing fails
        /// then a portion of the buffer may still have been consumed. It is
        /// recommended that you maintain your own copy.
        /// Upon failure a `PublicParserError` will be thrown.
        /// - parameter buffer: The consumable buffer to parse.
        /// - returns: A `ClientCommand` if parsing was successful.
        internal mutating func parseCommand(buffer: inout ByteBuffer) throws -> NIOIMAP.Command {
            return try GrammarParser.parseCommand(buffer: &buffer, tracker: .new)
        }

    }
}
