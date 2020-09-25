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

public struct ResponseParser: Parser {
    enum AttributeState: Equatable {
        case head
        case attribute
        case separator
    }

    public enum Mode: Equatable {
        case greeting
        case response
        case attributeBytes(Int)
    }

    let bufferLimit: Int
    private var mode: Mode

    public init(bufferLimit: Int = 1_000, expectGreeting: Bool = true) {
        self.bufferLimit = bufferLimit
        self.mode = expectGreeting ? .greeting : .response
    }

    public mutating func parseResponseStream(buffer: inout ByteBuffer) throws -> ResponseOrContinueRequest? {
        let tracker = StackTracker.makeNewDefaultLimitStackTracker
        do {
            switch self.mode {
            case .greeting:
                return try .response(self.parseGreeting(buffer: &buffer, tracker: tracker))
            case .response:
                return try self.parseResponse(buffer: &buffer, tracker: tracker)
            case .attributeBytes(let remaining):
                return .response(self.parseBytes(buffer: &buffer, remaining: remaining))
            }
        } catch is _IncompleteMessage {
            return nil
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

// MARK: - Parse greeting

extension ResponseParser {
    fileprivate mutating func parseGreeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
        let greeting = try GrammarParser.parseGreeting(buffer: &buffer, tracker: tracker)
        return self.moveStateMachine(expected: .greeting, next: .response, returnValue: .untaggedResponse(.greeting(greeting)))
    }
}

// MARK: - Parse responses

extension ResponseParser {
    fileprivate mutating func parseResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinueRequest {
        func parseResponse_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
            let response = try GrammarParser.parseFetchResponse(buffer: &buffer, tracker: tracker)
            return .fetchResponse(response)
        }

        func parseResponse_normal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
            let response = try GrammarParser.parseResponseData(buffer: &buffer, tracker: tracker)
            return .untaggedResponse(response)
        }

        func parseResponse_fetch_end(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
            try GrammarParser.fixedString(")", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return .fetchResponse(.finish)
        }

        return try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try? GrammarParser.space(buffer: &buffer, tracker: tracker)
            do {
                let response = try GrammarParser.oneOf([
                    parseResponse_fetch,
                    parseResponse_normal,
                    parseResponse_fetch_end,
                ], buffer: &buffer, tracker: tracker)
                switch response {
                case .fetchResponse(.streamingEnd): // FETCH MESS (1 2 3 4)
                    try? GrammarParser.space(buffer: &buffer, tracker: tracker)
                case .fetchResponse(.streamingBegin(kind: _, byteCount: let size)):
                    self.moveStateMachine(expected: .response, next: .attributeBytes(size))
                default:
                    break
                }
                return .response(response)
            } catch is ParserError {
                return try self._parseResponse(buffer: &buffer, tracker: tracker)
            }
        }
    }

    private mutating func _parseResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinueRequest {
        func parseResponse_continuation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinueRequest {
            .continueRequest(try GrammarParser.parseContinueRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinueRequest {
            .response(.taggedResponse(try GrammarParser.parseTaggedResponse(buffer: &buffer, tracker: tracker)))
        }

        return try GrammarParser.oneOf([
            parseResponse_continuation,
            parseResponse_tagged,
        ], buffer: &buffer, tracker: tracker)
    }
}

// MARK: - Parse bytes

extension ResponseParser {
    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    fileprivate mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> Response {
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
