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
            case messageAttributes
            case greeting
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
                let line = try self.parseLine(buffer: &buffer)
                if case .response(.body(.whole(.responseData(.messageData(.fetch(_, firstAttribute: .static(.bodySectionText(_, let size)))))))) = line {
                    self.mode = .bytes(size)
                } else if case .response(.body(.whole(.responseData(.messageData(.fetch(_, firstAttribute: _)))))) = line {
                    self.mode = .messageAttributes
                }
                return line
            case .greeting:
                let greeting = try GrammarParser.parseGreeting(buffer: &buffer, tracker: .new)
                self.mode = .lines
                return .greeting(greeting)
            case .messageAttributes:
                guard let att = try GrammarParser.parseMessageAttributeMiddle(buffer: &buffer, tracker: .new) else {
                    self.mode = .lines
                    return try self.parseResponseStream(buffer: &buffer)
                }
                if case NIOIMAP.MessageAttributeType.static(NIOIMAP.MessageAttributesStatic.bodySectionText(_, let size)) = att {
                    self.mode = .bytes(size)
                }
                return .response(.body(.messageAttribute(att)))
            }
        }
        
        /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
        /// only those that are required will be extracted. If not enough bytes are provided then the given
        /// `ByteBuffer` will be emptied.
        /// - parameter buffer: The buffer from which bytes should be extracted.
        /// - returns: A new `ByteBuffer` containing extracted bytes.
        mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> ResponseStream {
            if buffer.readableBytes >= remaining {
                let bytes = buffer.readSlice(length: remaining)!
                self.mode = .messageAttributes
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
        func parseLine(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            return .response(try self.parseResponseComponent(buffer: &buffer, tracker: .new))
        }
        
        func parseResponseComponent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseComponentStream {
            
            func parseResponseComponent_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseComponentStream {
                return .body(try self.parseResponseBody(buffer: &buffer, tracker: tracker))
            }
            
            func parseResponseComponent_end(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseComponentStream {
                return .end(try GrammarParser.parseResponseDone(buffer: &buffer, tracker: tracker))
            }
            
            return try ParserLibrary.parseOneOf([
                parseResponseComponent_body,
                parseResponseComponent_end
            ], buffer: &buffer, tracker: .new)
        }
        
        func parseResponseBody(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseBodyStream {
        
            func parseResponseBody_whole(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseBodyStream {
                return .whole(try GrammarParser.parseResponseType(buffer: &buffer, tracker: tracker))
            }
            
            func parseResponseBody_messageAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.ResponseBodyStream {
                return .messageAttribute(try GrammarParser.parseMessageAttribute_dynamicOrStatic(buffer: &buffer, tracker: tracker))
            }
            
            return try ParserLibrary.parseOneOf([
                parseResponseBody_whole,
                parseResponseBody_messageAttribute
            ], buffer: &buffer, tracker: tracker)
        }
    }
}
