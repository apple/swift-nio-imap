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

    public struct ResponseParser {

        enum Mode: Equatable {
            case lines
            case bytes(Int)
        }

        private(set) var mode: Mode = .lines

        let bufferLimit = 80_000

        public init() {

        }

        public mutating func parseResponseStream(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            switch self.mode {
            case .bytes(let remaining):
                return self.parseBytes(buffer: &buffer, remaining: remaining)
            case .lines:
                return try self.parseLine(buffer: &buffer)
            }
        }
        
        /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
        /// only those that are required will be extracted. If not enough bytes are provided then the given
        /// `ByteBuffer` will be emptied.
        /// - parameter buffer: The buffer from which bytes should be extracted.
        /// - returns: A new `ByteBuffer` containing extracted bytes.
        public mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> ResponseStream {
            if buffer.readableBytes >= remaining {
                let bytes = buffer.readSlice(length: remaining)!
                self.mode = .lines
                return .bytes(bytes)
            }
            
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            self.mode = .bytes(remaining - bytes.readableBytes)
            return .bytes(bytes)
        }

        /// Attempts to parse a given `ByteBuffer` into a `ClientCommand`
        /// Note that the `ByteBuffer` argument is consumable. If parsing fails
        /// then a portion of the buffer may still have been consumed. It is
        /// recommended that you maintain your own copy.
        /// Upon failure a `PublicParserError` will be thrown.
        /// - parameter buffer: The consumable buffer to parse.
        /// - returns: A `ClientCommand` if parsing was successful.
        public mutating func parseLine(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            return try ParserLibrary.parseOneOf([
                self.parseResponse,
                self.parseGreeting
            ], buffer: &buffer, tracker: .new)
        }
        
        func parseResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseStream {
            func parseLine_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseStream {
                return .body(try GrammarParser.parseResponseType(buffer: &buffer, tracker: tracker))
            }
            
            func parseLine_end(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseStream {
                return .end(try GrammarParser.parseResponse(buffer: &buffer, tracker: tracker))
            }
            
            return try ParserLibrary.parseOneOf([
                parseLine_body,
                parseLine_end
            ], buffer: &buffer, tracker: tracker)
        }
        
        func parseGreeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseStream {
            return .greeting(try GrammarParser.parseGreeting(buffer: &buffer, tracker: tracker))
        }

    }
}
