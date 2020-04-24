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

import struct NIO.ByteBuffer

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
            case attributeBytes(Int)
        }

        let bufferLimit: Int
        var mode: Mode = .greeting

        public init(bufferLimit: Int = 1_000) {
            self.bufferLimit = bufferLimit
        }

        public mutating func parseResponseStream(buffer: inout ByteBuffer) throws -> NIOIMAP.Response {
            switch self.mode {
            case .greeting:
                return try self.parseGreeting(buffer: &buffer)
            case .response:
                return try self.parseResponse(buffer: &buffer)
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

extension NIOIMAP.ResponseParser {
    fileprivate mutating func parseGreeting(buffer: inout ByteBuffer) throws -> NIOIMAP.Response {
        let greeting = try NIOIMAP.GrammarParser.parseGreeting(buffer: &buffer, tracker: .new)
        return self.moveStateMachine(expected: .greeting, next: .response, returnValue: .greeting(greeting))
    }
}

// MARK: - Parse responses

extension NIOIMAP.ResponseParser {
    fileprivate mutating func parseResponse(buffer: inout ByteBuffer) throws -> NIOIMAP.Response {
        func parseResponse_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Response {
            let response = try NIOIMAP.GrammarParser.parseFetchResponse(buffer: &buffer, tracker: tracker)
            return .fetchResponse(response)
        }

        func parseResponse_normal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Response {
            let response = try NIOIMAP.GrammarParser.parseResponseData(buffer: &buffer, tracker: tracker)
            return .untaggedResponse(response)
        }

        try? ParserLibrary.parseSpace(buffer: &buffer, tracker: .new)
        do {
            let response = try ParserLibrary.parseOneOf([
                parseResponse_fetch,
                parseResponse_normal,
            ], buffer: &buffer, tracker: .new)
            switch response {
            case .fetchResponse(.streamingEnd):
                try? ParserLibrary.parseSpace(buffer: &buffer, tracker: .new)
            case .fetchResponse(.streamingBegin(type: _, size: let size)):
                self.moveStateMachine(expected: .response, next: .attributeBytes(size))
            default:
                break
            }
            return response
        } catch is ParserError {
            return try self._parseResponse(buffer: &buffer)
        }
    }

    private mutating func _parseResponse(buffer: inout ByteBuffer) throws -> NIOIMAP.Response {
        func parseResponse_continuation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Response {
            .continuationRequest(try NIOIMAP.GrammarParser.parseContinueRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NIOIMAP.Response {
            .taggedResponse(try NIOIMAP.GrammarParser.parseTaggedResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponse_continuation,
            parseResponse_tagged,
        ], buffer: &buffer, tracker: .new)
    }
}

// MARK: - Parse bytes

extension NIOIMAP.ResponseParser {
    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    fileprivate mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> NIOIMAP.Response {
        if remaining == 0 {
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .response,
                returnValue: .fetchResponse(.streamingEnd)
            )
        } else if buffer.readableBytes >= remaining {
            let bytes = buffer.readSlice(length: remaining)!
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(0),
                returnValue: .fetchResponse(.streamingBytes(bytes))
            )
        } else {
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            let leftToRead = remaining - bytes.readableBytes
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(leftToRead),
                returnValue: .fetchResponse(.streamingBytes(bytes))
            )
        }
    }
}
