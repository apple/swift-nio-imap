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
    enum AttributeState: Hashable {
        case head
        case attribute
        case separator
    }

    enum ResponseState: Hashable {
        case fetchOrNormal
        case fetchMiddle
    }

    enum Mode: Hashable {
        case response(ResponseState)
        case streamingQuoted
        case attributeBytes(Int)
    }

    let parser = GrammarParser()
    let bufferLimit: Int
    private var mode: Mode

    /// Creates a new `ResponseParser`.
    /// - parameter bufferLimit: The maximum amount of data that may be buffered by the parser. If this limit is exceeded then an error will be thrown. Defaults to 1000 bytes.
    public init(bufferLimit: Int = 8_192) {
        self.bufferLimit = bufferLimit
        self.mode = .response(.fetchOrNormal)
    }

    /// Parses a `ResponseStream` and returns the result.
    /// - parameter buffer: The `ByteBuffer` to parse data from.
    /// - returns: `nil` if there wasn't enough data, otherwise a `ResponseOrContinuationRequest` if parsing was successful.
    /// - throws: A `ParserError` with a desription as to why parsing failed.
    public mutating func parseResponseStream(buffer inputBytes: inout ByteBuffer) throws -> ResponseOrContinuationRequest? {
        let tracker = StackTracker.makeNewDefaultLimitStackTracker
        var parseBuffer = ParseBuffer(inputBytes)
        defer {
            assert(inputBytes.readableBytes >= parseBuffer.readableBytes,
                   "illegal state, parse buffer has more remaining than input had: \(inputBytes), \(parseBuffer)")

            // Discard everything that has been parsed off.
            inputBytes.moveReaderIndex(forwardBy: inputBytes.readableBytes - parseBuffer.readableBytes)
        }
        do {
            switch self.mode {
            case .response(let state):
                return try self.parseResponse(state: state, buffer: &parseBuffer, tracker: tracker)
            case .attributeBytes(let remaining):
                return .response(try self.parseBytes(buffer: &parseBuffer, tracker: tracker, remaining: remaining))
            case .streamingQuoted:
                return .response(try self.parseQuotedBytes(buffer: &parseBuffer))
            }
        } catch is IncompleteMessage {
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
    fileprivate mutating func parseResponse(state: ResponseState, buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
        enum _Response: Hashable {
            case untaggedResponse(ResponsePayload)
            case fetchResponse(GrammarParser._FetchResponse)
        }

        func parseResponse_fetch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _Response {
            switch state {
            case .fetchOrNormal:
                return .fetchResponse(try self.parser.parseFetchResponseStart(buffer: &buffer, tracker: tracker))
            case .fetchMiddle:
                return .fetchResponse(try self.parser.parseFetchResponse(buffer: &buffer, tracker: tracker))
            }
        }

        func parseResponse_normal(buffer: inout ParseBuffer, tracker: StackTracker) throws -> _Response {
            let response = try self.parser.parseResponseData(buffer: &buffer, tracker: tracker)
            return .untaggedResponse(response)
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try? PL.parseSpaces(buffer: &buffer, tracker: tracker)
            do {
                let response = try PL.parseOneOf(
                    parseResponse_fetch, parseResponse_normal,
                    buffer: &buffer,
                    tracker: tracker
                )
                switch response {
                case .fetchResponse(.start(let num)):
                    self.moveStateMachine(expected: .response(.fetchOrNormal), next: .response(.fetchMiddle))
                    return .response(.fetch(.start(num)))
                case .fetchResponse(.literalStreamingBegin(kind: let kind, byteCount: let size)):
                    self.moveStateMachine(expected: .response(.fetchMiddle), next: .attributeBytes(size))
                    return .response(.fetch(.streamingBegin(kind: kind, byteCount: size)))

                case .fetchResponse(.quotedStreamingBegin(kind: let kind, byteCount: let size)):
                    self.moveStateMachine(expected: .response(.fetchMiddle), next: .streamingQuoted)
                    return .response(.fetch(.streamingBegin(kind: kind, byteCount: size)))

                case .fetchResponse(.finish):
                    self.moveStateMachine(expected: .response(.fetchMiddle), next: .response(.fetchOrNormal))
                    return .response(.fetch(.finish))

                case .untaggedResponse(let payload):
                    return .response(.untagged(payload))

                case .fetchResponse(.simpleAttribute(let att)):
                    return .response(.fetch(.simpleAttribute(att)))
                }
            } catch is ParserError {
                return try self._parseResponse(buffer: &buffer, tracker: tracker)
            }
        }
    }

    private func _parseResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
        func parseResponse_continuation(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
            .continuationRequest(try self.parser.parseContinuationRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ResponseOrContinuationRequest {
            .response(.tagged(try self.parser.parseTaggedResponse(buffer: &buffer, tracker: tracker)))
        }

        return try PL.parseOneOf([
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
    fileprivate mutating func parseBytes(buffer: inout ParseBuffer, tracker: StackTracker, remaining: Int) throws -> Response {
        if remaining == 0 {
            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .response(.fetchMiddle),
                returnValue: .fetch(.streamingEnd)
            )
        } else {
            let bytes = try PL.parseBytes(buffer: &buffer,
                                          tracker: .makeNewDefaultLimitStackTracker,
                                          upTo: remaining)
            let leftToRead = remaining - bytes.readableBytes
            assert(leftToRead >= 0, "\(leftToRead) is negative")

            return self.moveStateMachine(
                expected: .attributeBytes(remaining),
                next: .attributeBytes(leftToRead),
                returnValue: .fetch(.streamingBytes(bytes))
            )
        }
    }

    fileprivate mutating func parseQuotedBytes(buffer: inout ParseBuffer) throws -> Response {
        let quoted = try self.parser.parseQuoted(buffer: &buffer, tracker: .makeNewDefaultLimitStackTracker)
        return self.moveStateMachine(expected: .streamingQuoted, next: .attributeBytes(0), returnValue: .fetch(.streamingBytes(quoted)))
    }
}
