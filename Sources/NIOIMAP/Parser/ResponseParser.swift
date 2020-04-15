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
            case head
            case attribute
            case separator
        }
        
        enum Mode: Equatable {
            case greeting
            case response
            case attributes(AttributeState)
            case attributeBytes(Int)
        }

        let bufferLimit: Int
        var mode: Mode = .greeting

        public init(bufferLimit: Int = 1_000) {
            self.bufferLimit = bufferLimit
        }

        public mutating func parseResponseStream(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
            switch self.mode {
            case .greeting:
                return try self.parseGreeting(buffer: &buffer)
            case .response:
                return try self.parseResponse(buffer: &buffer)
            case .attributes(let state):
                return try self.parseAtributes(state: state, buffer: &buffer)
            case .attributeBytes(let remaining):
                return self.parseBytes(buffer: &buffer, remaining: remaining)
            }
        }
        
        private mutating func moveStateMachine<T>(expected: Mode, next: Mode, then: () throws -> T) rethrows -> T {
            if case expected = self.mode {
                self.mode = next
                return try then()
            } else {
                fatalError("Unexpected state \(self.mode)")
            }
        }
        
        private mutating func moveStateMachine(expected: Mode, next: Mode) {
            if self.mode == expected {
                self.mode = next
            } else {
                fatalError("Unexpected state \(self.mode)")
            }
        }
    }
}

// MARK: - Parse greeting
extension NIOIMAP.ResponseParser {
    
    fileprivate mutating func parseGreeting(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
        let greeting = try NIOIMAP.GrammarParser.parseGreeting(buffer: &buffer, tracker: .new)
        return self.moveStateMachine(expected: .greeting, next: .response) {
            .greeting(greeting)
        }
    }
    
}

// MARK: - Parse responses
extension NIOIMAP.ResponseParser {

    fileprivate mutating func parseResponse(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
        do {
            let response = try NIOIMAP.GrammarParser.parseResponseData(buffer: &buffer, tracker: .new)
            if case .messageData(.fetch(_)) = response {
                self.moveStateMachine(expected: .response, next: .attributes(.head))
            }
            return .responseBegin(response)
        } catch is ParserError {
            // no response? we must be at response end
            return .responseEnd(try NIOIMAP.GrammarParser.parseResponseDone(buffer: &buffer, tracker: .new))
        }
    }
    
}

// MARK: - Parse attributes
extension NIOIMAP.ResponseParser {
    
    fileprivate mutating func parseAtributes(state: AttributeState, buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
        
        switch state {
        case .head:
            try NIOIMAP.GrammarParser.parseMessageAttributeStart(buffer: &buffer, tracker: .new)
            return self.moveStateMachine(expected: .attributes(.head), next: .attributes(.attribute)) {
                .attributesStart
            }
        case .separator:
            do {
                try NIOIMAP.GrammarParser.parseMessageAttributeMiddle(buffer: &buffer, tracker: .new)
                self.moveStateMachine(expected: .attributes(.separator), next: .attributes(.attribute))
                return try self.parseSingleAttribute(buffer: &buffer)
            } catch is ParserError {
                try NIOIMAP.GrammarParser.parseMessageAttributeEnd(buffer: &buffer, tracker: .new)
                return self.moveStateMachine(expected: .attributes(.separator), next: .response) {
                    .attributesFinish
                }
            }
        case .attribute:
            return try self.parseSingleAttribute(buffer: &buffer)
        }
        
    }
    
    private mutating func parseSingleAttribute(buffer: inout ByteBuffer) throws -> NIOIMAP.ResponseStream {
        let att = try NIOIMAP.GrammarParser.parseMessageAttribute_dynamicOrStatic(buffer: &buffer, tracker: .new)
        switch att {
        case .static(.bodySectionText(let optional, let size)):
            return self.moveStateMachine(expected: .attributes(.attribute), next: .attributeBytes(size)) {
                .streamingAttributeBegin(NIOIMAP.MessageAttributesStatic.bodySectionText(optional, size))
            }
        default:
            return self.moveStateMachine(expected: .attributes(.attribute), next: .attributes(.separator)) {
                .simpleAttribute(att)
            }
        }
    }
    
}

// MARK: - Parse bytes
extension NIOIMAP.ResponseParser {

    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    fileprivate mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> NIOIMAP.ResponseStream {
        if remaining == 0 {
            return self.moveStateMachine(expected: .attributeBytes(remaining), next: .attributes(.separator)) {
                .streamingAttributeEnd
            }
        } else if buffer.readableBytes >= remaining {
            let bytes = buffer.readSlice(length: remaining)!
            return self.moveStateMachine(expected: .attributeBytes(remaining), next: .attributeBytes(0)) {
                .streamingAttributeBytes(bytes)
            }
        } else {
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            let leftToRead = remaining - bytes.readableBytes
            return self.moveStateMachine(expected: .attributeBytes(remaining), next: .attributeBytes(leftToRead)) {
                .streamingAttributeBytes(bytes)
            }
        }
    }
    
}
