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

    public struct ResponseParser: Parser {

        enum AttributeState: Equatable {
            case first
            case middle
        }
        
        enum Mode: Equatable {
            case greeting
            case response
            case attributes(AttributeState)
            case attributeBytes(Int)
        }

        let bufferLimit: Int
        var mode: Mode = .greeting
        private var framingParser: IMAPFramingParser

        public init(bufferLimit: Int = 1_000) {
            self.bufferLimit = bufferLimit
            self.framingParser = IMAPFramingParser(bufferSizeLimit: bufferLimit)
        }

        public mutating func parseResponseStream(buffer overallBuffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream? {
            let framingResult = try self.framingParser.parse(&overallBuffer)
            print((framingResult.line?.readableBytesView).map { String(decoding: $0, as: Unicode.UTF8.self) }.debugDescription)

            if var line = framingResult.line {
                let response = try self.parsePreFramedLine(&line)
                print("--> \(response)")
                if line.readableBytes != 0 {
                    // There are left-overs after parsing a pre-framed line. This can only mean we're streaming, or
                    // some bug of course.
                    assert(response.isStreamingResponse,
                           """
                           BUG in the SwiftNIO IMAP Parser (please report): We received the IMAP frame \
                           '\(String(decoding: framingResult.line!.readableBytesView, as: Unicode.UTF8.self))' which \
                           should parse into exactly IMAP response unless it's a response we stream. The parsed \
                           response \(response) however isn't marked as a streaming response.
                           """)
                    // ok, let's unparse the left-overs
                    overallBuffer.moveReaderIndex(to: overallBuffer.readerIndex - line.readableBytes)
                    // let's make sure we unparsed the right stuff.
                    assert(overallBuffer.readableBytesView.starts(with: line.readableBytesView))
                }
                return response
            } else {
                return nil
            }
        }

        private mutating func parsePreFramedLine(_ buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            switch self.mode {
            case .greeting:
                let greeting = try GrammarParser.parseGreeting(buffer: &buffer, tracker: .new)
                self.mode = .response
                return .greeting(greeting)
            case .response:
                return try self.parseResponse(buffer: &buffer)
            case .attributes(let state):
                return try self.parseAtributes(state: state, buffer: &buffer)
            case .attributeBytes(let remaining):
                return self.parseBytes(buffer: &buffer, remaining: remaining)
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
                self.mode = .attributes(.middle)
                return .attributeBytes(bytes)
            }
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            let leftToRead = remaining - bytes.readableBytes
            self.mode = .attributeBytes(leftToRead)
            return .attributeBytes(bytes)
        }
        
        mutating func parseAtributes(state: AttributeState, buffer: inout ByteBuffer) throws -> ResponseStream {
            
            switch state {
            case .first:
                try GrammarParser.parseMessageAttributeStart(buffer: &buffer, tracker: .new)
            case .middle:
                do {
                    try GrammarParser.parseMessageAttributeMiddle(buffer: &buffer, tracker: .new)
                } catch {
                    try GrammarParser.parseMessageAttributeEnd(buffer: &buffer, tracker: .new)
                    return try self.parseResponse(buffer: &buffer)
                }
            }
            
            var save = buffer
            do {
                let att = try GrammarParser.parseMessageAttribute_dynamicOrStatic(buffer: &buffer, tracker: .new)
                let returnVal: ResponseStream
                switch att {
                case .static(.bodySectionText(let optional, let size)):
                    self.mode = .attributeBytes(size)
                    returnVal = .attributeBegin(NIOIMAP.MessageAttributesStatic.bodySectionText(optional, size))
                default:
                    returnVal = .simpleAttribute(att)
                    self.mode = .attributes(.middle)
                }
                if state == .middle {
                    do {
                        try GrammarParser.parseMessageAttributeEnd(buffer: &buffer, tracker: .new)
                        self.mode = .response
                    } catch is ParserError {
                        /// do nothing, we aren't ready to end
                    }
                }
                
                return returnVal
            } catch is ParserError {
                self.mode = .response // if there isn't a next attribute then it's time for the next response
                return try self.parseResponse(buffer: &save)
            }
        }
        
        mutating func parseResponse(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            do {
                let response = try GrammarParser.parseResponseData(buffer: &buffer, tracker: .new)
                if case .messageData(.fetch(_)) = response {
                    self.mode = .attributes(.first)
                }
                return .responseBegin(response)
            } catch is ParserError {
                // no response? we must be at response end
                return .responseEnd(try GrammarParser.parseResponseDone(buffer: &buffer, tracker: .new))
            }
        }
    }
}
