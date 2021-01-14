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

/// A parser to be used by Clients in order to parse responses sent from a server.
public struct ResponseParser: Parser {
    enum AttributeState: Equatable {
        case head
        case attribute
        case separator
    }

    enum ResponseState: Equatable {
        case fetchOrNormal
        case fetchMiddle
    }

    enum Mode: Equatable {
        case response(ResponseState)
        case streamingQuoted
        case attributeBytes(Int)
    }

    let bufferLimit: Int
    private var mode: Mode

    /// Creates a new `ResponseParser`.
    /// - parameter bufferLimit: The maximum amount of data that may be buffered by the parser. If this limit is exceeded then an error will be thrown. Defaults to 1000 bytes.
    public init(bufferLimit: Int = 1_000) {
        self.bufferLimit = bufferLimit
        self.mode = .response(.fetchOrNormal)
    }

    /// Parses a `ResponseStream` and returns the result.
    /// - parameter buffer: The `ByteBuffer` to parse data from.
    /// - returns: `nil` if there wasn't enough data, otherwise a `ResponseOrContinuationRequest` if parsing was successful.
    /// - throws: A `ParserError` with a desription as to why parsing failed.
    public mutating func parseResponseStream(buffer: inout ByteBuffer) throws -> ResponseOrContinuationRequest? {
        let tracker = StackTracker.makeNewDefaultLimitStackTracker
        do {
            switch self.mode {
            case .response(let state):
                return try self.parseResponse(state: state, buffer: &buffer, tracker: tracker)
            case .attributeBytes(let remaining):
                return .response(try self.parseBytes(buffer: &buffer, remaining: remaining))
            case .streamingQuoted:
                return .response(try self.parseUnknownBytes(buffer: &buffer))
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

// MARK: - Parse responses

extension ResponseParser {
    fileprivate mutating func parseResponse(state: ResponseState, buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
        func parseResponse_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
            switch state {
            case .fetchOrNormal:
                return .fetchResponse(try GrammarParser.parseFetchResponseStart(buffer: &buffer, tracker: tracker))
            case .fetchMiddle:
                return .fetchResponse(try GrammarParser.parseFetchResponse(buffer: &buffer, tracker: tracker))
            }
        }

        func parseResponse_normal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Response {
            let response = try GrammarParser.parseResponseData(buffer: &buffer, tracker: tracker)
            return .untaggedResponse(response)
        }

        return try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try? GrammarParser.space(buffer: &buffer, tracker: tracker)
            do {
                let response = try GrammarParser.oneOf([
                    parseResponse_normal,
                    parseResponse_fetch,
                ], buffer: &buffer, tracker: tracker)

                switch response {
                case .fetchResponse(.start(_)):
                    self.moveStateMachine(expected: .response(.fetchOrNormal), next: .response(.fetchMiddle))
                case .fetchResponse(.streamingEnd): // FETCH MESS (1 2 3 4)
                    try? GrammarParser.space(buffer: &buffer, tracker: tracker)
                case .fetchResponse(.streamingBegin(kind: _, byteCount: let size)):
                    if let size = size {
                        self.moveStateMachine(expected: .response(.fetchMiddle), next: .attributeBytes(size))
                    } else {
                        self.moveStateMachine(expected: .response(.fetchMiddle), next: .streamingQuoted)
                    }
                case .fetchResponse(.finish):
                    self.moveStateMachine(expected: .response(.fetchMiddle), next: .response(.fetchOrNormal))
                default:
                    break
                }

                return .response(response)
            } catch is ParserError {
                return try self._parseResponse(buffer: &buffer, tracker: tracker)
            }
        }
    }

    private mutating func _parseResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
        func parseResponse_continuation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
            .continuationRequest(try GrammarParser.parseContinuationRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
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
    fileprivate mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) throws -> Response {
        if remaining == 0 {
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .response(.fetchMiddle),
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
            
            guard buffer.readableBytes > 0 else {
                throw _IncompleteMessage()
            }
            
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            let leftToRead = remaining - bytes.readableBytes
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(leftToRead),
                returnValue: .fetchResponse(.streamingBytes(bytes))
            )
        }
    }

    fileprivate mutating func parseUnknownBytes(buffer: inout ByteBuffer) throws -> Response {
        let quoteIndex = buffer.readableBytesView.firstIndex(of: UInt8(ascii: "\""))
        if let quoteIndex = quoteIndex {
            let slice = buffer.readableBytesView[..<quoteIndex]
            if slice.count > 0 {
                buffer.moveReaderIndex(to: quoteIndex)
                let parsedBuffer = ByteBuffer(bytes: slice)
                let response = FetchResponse.streamingBytes(parsedBuffer)
                return .fetchResponse(response)
            } else {
                buffer.moveReaderIndex(forwardBy: 1)
                return self.moveStateMachine(expected: .streamingQuoted, next: .response(.fetchMiddle), returnValue: .fetchResponse(.streamingEnd))
            }
        } else {
            
            guard buffer.readableBytes > 0 else {
                throw _IncompleteMessage()
            }
            
            let bytes = buffer.readSlice(length: buffer.readableBytes)!
            return .fetchResponse(.streamingBytes(bytes))
        }
    }
}
