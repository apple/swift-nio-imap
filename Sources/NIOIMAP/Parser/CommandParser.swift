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

    public struct CommandParser {

        enum Mode: Equatable {
            case lines
            case idle
            case bytes(Int)
        }

        private(set) var mode: Mode = .lines

        let bufferLimit = 80_000

        public init() {

        }
        
        /// Parses a given `ByteBuffer` into a `CommandStream` that may then be transmitted.
        /// Parsing depends on the current mode of the parser.
        /// - parameter buffer: A `ByteBuffer` that will be consumed for parsing.
        /// - returns: A `CommandStream` that can be sent.
        public mutating func parseCommandStream(buffer: inout ByteBuffer) throws -> NIOIMAP.CommandStream {
            switch self.mode {
            case .bytes(let remaining):
                let bytes = self.parseBytes(buffer: &buffer, remaining: remaining)
                try ParserLibrary.parseNewline(buffer: &buffer, tracker: .new)
                return .bytes(bytes)
            case .idle:
                try GrammarParser.parseIdleDone(buffer: &buffer, tracker: .new)
                self.mode = .lines
                return .idleDone
            case .lines:
                let command = try self.parseCommand(buffer: &buffer)
                if case .append(to: _, firstMessageMetadata: let firstMetdata) = command.type {
                    if case .literal(let size) = firstMetdata.data {
                        self.mode = .bytes(size)
                    } else if case .literal8(let size) = firstMetdata.data {
                        self.mode = .bytes(size)
                    }
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
        public mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> ByteBuffer {
            if buffer.readableBytes >= remaining {
                let bytes = buffer.readSlice(length: remaining)!
                self.mode = .lines
                return bytes
            }
            
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            self.mode = .bytes(remaining - bytes.readableBytes)
            return bytes
        }

        /// Attempts to parse a given `ByteBuffer` into a `ClientCommand`
        /// Note that the `ByteBuffer` argument is consumable. If parsing fails
        /// then a portion of the buffer may still have been consumed. It is
        /// recommended that you maintain your own copy.
        /// Upon failure a `PublicParserError` will be thrown.
        /// - parameter buffer: The consumable buffer to parse.
        /// - returns: A `ClientCommand` if parsing was successful.
        public mutating func parseCommand(buffer: inout ByteBuffer) throws -> NIOIMAP.Command {

            // try to find LF in the first `self.bufferLimit` bytes
            guard buffer.readableBytesView.prefix(self.bufferLimit).contains(UInt8(ascii: "\n")) else {
                // We're in line-parsing mode and there's no newline, let's buffer more. But let's do a quick check
                // that don't buffer too much.
                guard buffer.readableBytes <= self.bufferLimit else {
                    // We're in line parsing mode
                    throw ParsingError.lineTooLong
                }
                throw ParsingError.incompleteMessage
            }

            do {
                let command = try GrammarParser.parseCommand(buffer: &buffer, tracker: .new)
                return command
            } catch is ParsingError {
                throw ParsingError.incompleteMessage
            }
        }

        public mutating func parseServerResponse(buffer: inout ByteBuffer) throws -> NIOIMAP.ServerResponse {
            func parseServerResponse_greeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ServerResponse {
                return .greeting(try GrammarParser.parseGreeting(buffer: &buffer, tracker: tracker))
            }
            func parseServerResponse_response(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ServerResponse {
                return .response(try GrammarParser.parseResponse(buffer: &buffer, tracker: tracker))
            }
            return try ParserLibrary.parseOneOf([
                parseServerResponse_greeting,
                parseServerResponse_response
            ], buffer: &buffer, tracker: .new)
        }

    }
}
