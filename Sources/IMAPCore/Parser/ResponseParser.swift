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

extension IMAPCore {

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

        public mutating func parseResponseStream<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType) throws -> IMAPCore.ResponseStream {
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
        
        
        private mutating func moveStateMachine<Return>(expected: Mode, next: Mode, returnValue: Return) -> Return {
            if case expected = self.mode {
                self.mode = next
                return returnValue
            } else {
                fatalError("Unexpected state \(self.mode)")
            }
        }
        
        private mutating func moveStateMachine(expected: Mode, next: Mode) {
            self.moveStateMachine(expected: expected, next: next, returnValue: ())
        }
    }
}

// MARK: - Parse greeting
extension IMAPCore.ResponseParser {
    
    fileprivate mutating func parseGreeting<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType) throws -> IMAPCore.ResponseStream {
        let greeting = try IMAPCore.GrammarParser.parseGreeting(buffer: &buffer, tracker: .new)
        return self.moveStateMachine(expected: .greeting, next: .response, returnValue: .greeting(greeting))
    }
    
}

// MARK: - Parse responses
extension IMAPCore.ResponseParser {

    fileprivate mutating func parseResponse<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType) throws -> IMAPCore.ResponseStream {
        do {
            let response = try IMAPCore.GrammarParser.parseResponseData(buffer: &buffer, tracker: .new)
            if case .messageData(.fetch(_)) = response {
                self.moveStateMachine(expected: .response, next: .attributes(.head))
            }
            return .responseBegin(response)
        } catch is ParserError {
            // no response? we must be at response end
            return .responseEnd(try IMAPCore.GrammarParser.parseResponseDone(buffer: &buffer, tracker: .new))
        }
    }
    
}

// MARK: - Parse attributes
extension IMAPCore.ResponseParser {
    
    fileprivate mutating func parseAtributes<ByteBufferType: ByteBufferProtocol>(state: AttributeState, buffer: inout ByteBufferType) throws -> IMAPCore.ResponseStream {
        
        switch state {
        case .head:
            try IMAPCore.GrammarParser.parseMessageAttributeStart(buffer: &buffer, tracker: .new)
            return self.moveStateMachine(
                expected: .attributes(.head),
                next: .attributes(.attribute),
                returnValue: .attributesStart
            )
        case .separator:
            do {
                try IMAPCore.GrammarParser.parseMessageAttributeMiddle(buffer: &buffer, tracker: .new)
                self.moveStateMachine(expected: .attributes(.separator), next: .attributes(.attribute))
                return try self.parseSingleAttribute(buffer: &buffer)
            } catch is ParserError {
                try IMAPCore.GrammarParser.parseMessageAttributeEnd(buffer: &buffer, tracker: .new)
                return self.moveStateMachine(expected: .attributes(.separator), next: .response, returnValue: .attributesFinish)
            }
        case .attribute:
            return try self.parseSingleAttribute(buffer: &buffer)
        }
        
    }
    
    private mutating func parseSingleAttribute<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType) throws -> IMAPCore.ResponseStream {
        let att = try IMAPCore.GrammarParser.parseMessageAttribute_dynamicOrStatic(buffer: &buffer, tracker: .new)
        switch att {
        case .static(.bodySectionText(let optional, let size)):
            return self.moveStateMachine(
                expected: .attributes(.attribute),
                next: .attributeBytes(size),
                returnValue: .streamingAttributeBegin(IMAPCore.MessageAttributesStatic.bodySectionText(optional, size))
            )
        default:
            return self.moveStateMachine(
                expected: .attributes(.attribute),
                next: .attributes(.separator),
                returnValue: .simpleAttribute(att)
            )
        }
    }
    
}

// MARK: - Parse bytes
extension IMAPCore.ResponseParser {

    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    fileprivate mutating func parseBytes<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, remaining: Int) -> IMAPCore.ResponseStream {
        if remaining == 0 {
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributes(.separator),
                returnValue: .streamingAttributeEnd
            )
        } else if buffer.readableBytes >= remaining {
            var bytes = buffer.readSlice(length: remaining)!
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(0),
                returnValue: .streamingAttributeBytes(bytes.readBytes(length: bytes.readableBytes)!)
            )
        } else {
            var bytes = buffer.readSlice(length: buffer.readableBytes)!
            let leftToRead = remaining - bytes.readableBytes
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(leftToRead),
                returnValue: .streamingAttributeBytes(bytes.readBytes(length: bytes.readableBytes)!)
            )
        }
    }
    
}
