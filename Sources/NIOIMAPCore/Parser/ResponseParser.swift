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

/// Parsing a server response exceeded the maximum allowed message attributes.
///
/// Each ``MessageAttribute`` in a FETCH response is counted. If a server sends a FETCH
/// response with more attributes than allowed, this error is thrown. This is a DoS
/// protection limit.
///
/// - SeeAlso: ``MessageAttribute``, ``ExceededMaximumBodySizeError``
public struct ExceededMaximumMessageAttributesError: Error {
    /// The actual number of message attributes in the response.
    public var actualCount: Int

    /// The configured maximum number of attributes allowed.
    public var maximumCount: Int

    /// Creates a new error with the actual and maximum attribute counts.
    ///
    /// - Parameters:
    ///   - actualCount: The number of attributes encountered
    ///   - maximumCount: The configured limit
    public init(actualCount: Int, maximumCount: Int) {
        self.actualCount = actualCount
        self.maximumCount = maximumCount
    }
}

/// Parsing a server response exceeded the maximum allowed body size.
///
/// Server responses can include large message bodies (e.g., in FETCH responses).
/// If a body exceeds the configured maximum size, this error is thrown. This is a
/// DoS and memory protection limit.
///
/// - SeeAlso: ``ExceededMaximumMessageAttributesError``, ``ResponseParser/Options``
public struct ExceededMaximumBodySizeError: Error {
    /// The actual number of bytes in the body.
    public var actualCount: UInt64

    /// The configured maximum body size.
    public var maximumCount: UInt64

    /// Creates a new error with the actual and maximum body sizes.
    ///
    /// - Parameters:
    ///   - actualCount: The number of body bytes encountered
    ///   - maximumCount: The configured limit
    public init(actualCount: UInt64, maximumCount: UInt64) {
        self.actualCount = actualCount
        self.maximumCount = maximumCount
    }
}

/// A parser for IMAP server responses.
///
/// `ResponseParser` incrementally parses the stream of bytes sent by an IMAP server,
/// converting them into ``ResponseOrContinuationRequest`` values (which contain either
/// a ``Response`` or a ``ContinuationRequest``). It handles all response types defined
/// by RFC 3501 and supported extensions, including:
/// - Tagged responses (command completions)
/// - Untagged responses (unsolicited data, mailbox state changes)
/// - FETCH responses with streaming support
/// - Continuation requests for multi-part operations
///
/// The parser maintains internal state for handling responses that arrive incomplete
/// or fragmented across multiple network packets.
///
/// ## Usage
///
/// ```swift
/// var parser = ResponseParser()
/// var buffer = ByteBuffer(bytes: serverData)
/// while let response = try parser.parseResponseStream(buffer: &buffer) {
///     // Process response
/// }
/// ```
///
/// - SeeAlso: ``ResponseOrContinuationRequest``, ``Response``, ``ContinuationRequest``, ``Options``,
///   [RFC 3501 Section 7](https://datatracker.ietf.org/doc/html/rfc3501#section-7) (server responses)
public struct ResponseParser: Parser, Sendable {
    /// Configuration options for response parsing.
    ///
    /// `Options` allows tuning the parser's behavior and limits, particularly for
    /// DoS protection and memory management when dealing with potentially untrusted
    /// server responses.
    public struct Options: Sendable {
        /// The maximum amount of data the parser can buffer at any time.
        ///
        /// If the parser's internal buffer exceeds this limit, parsing fails. This
        /// prevents malformed responses from consuming excessive memory.
        /// Defaults to 8192 bytes.
        public var bufferLimit: Int

        /// The maximum number of message attributes allowed in a single FETCH response.
        ///
        /// Each attribute (BODY, FLAGS, ENVELOPE, etc.) in a FETCH response is counted.
        /// Defaults to `Int.max` (effectively unlimited).
        public var messageAttributeLimit: Int

        /// The maximum size of message body data in a single response.
        ///
        /// If a FETCH response includes body data larger than this limit, parsing fails.
        /// Defaults to `UInt64.max` (effectively unlimited).
        public var bodySizeLimit: UInt64

        /// The maximum size of a single literal in the response.
        ///
        /// Literals (data between `{size}` markers) larger than this limit will cause
        /// an error. Defaults to ``IMAPDefaults/literalSizeLimit`` (4096 bytes).
        public var literalSizeLimit: Int

        /// Optional string interning/caching function for parsed strings.
        ///
        /// When provided, every parsed string is passed through this function, which
        /// can return a cached version. This reduces memory usage for responses with
        /// many repeated strings (e.g., flag names). Defaults to `nil` (no caching).
        public var parsedStringCache: (@Sendable (String) -> String)?

        /// Creates new response parser options.
        ///
        /// - Parameters:
        ///   - bufferLimit: Maximum buffered bytes. Defaults to 8192.
        ///   - messageAttributeLimit: Maximum FETCH attributes. Defaults to Int.max.
        ///   - bodySizeLimit: Maximum body size. Defaults to UInt64.max.
        ///   - literalSizeLimit: Maximum literal size. Defaults to 4096 bytes.
        ///   - parsedStringCache: Optional string caching function. Defaults to nil.
        public init(
            bufferLimit: Int = 8_192,
            messageAttributeLimit: Int = .max,
            bodySizeLimit: UInt64 = .max,
            literalSizeLimit: Int = IMAPDefaults.literalSizeLimit,
            parsedStringCache: (@Sendable (String) -> String)? = nil
        ) {
            self.bufferLimit = bufferLimit
            self.messageAttributeLimit = messageAttributeLimit
            self.bodySizeLimit = bodySizeLimit
            self.literalSizeLimit = literalSizeLimit
            self.parsedStringCache = parsedStringCache
        }
    }

    enum AttributeState: Hashable, Sendable {
        case head
        case attribute
        case separator
    }

    enum ResponseState: Hashable, Sendable {
        case fetchOrNormal
        case fetchMiddle(attributeCount: Int)
    }

    enum Mode: Hashable, Sendable {
        case response(ResponseState)
        case streamingQuoted(attributeCount: Int)
        case attributeBytes(Int, attributeCount: Int)
    }

    let parser: GrammarParser
    let bufferLimit: Int
    let messageAttributeLimit: Int
    let bodySizeLimit: UInt64
    private var mode: Mode


    /// Creates a new `ResponseParser` with configuration options.
    ///
    /// - Parameter options: Configuration for buffer limits, size restrictions, and
    ///   optional string caching. Defaults to standard limits suitable for most servers.
    ///
    /// - SeeAlso: ``Options``
    public init(
        options: Options = Options()
    ) {
        self.bufferLimit = options.bufferLimit
        self.mode = .response(.fetchOrNormal)
        self.messageAttributeLimit = options.messageAttributeLimit
        self.parser = GrammarParser(
            literalSizeLimit: options.literalSizeLimit,
            parsedStringCache: options.parsedStringCache
        )
        self.bodySizeLimit = options.bodySizeLimit
    }

    /// Parses a server response from incoming bytes.
    ///
    /// Incrementally consumes bytes from the buffer and returns parsed responses.
    /// The parser maintains state across calls, so it can handle responses that arrive
    /// fragmented across multiple network packets.
    ///
    /// Returns `nil` when more data is needed. Throws an error if:
    /// - The buffer exceeds ``Options/bufferLimit``
    /// - A literal exceeds ``Options/literalSizeLimit``
    /// - A FETCH response has too many attributes (exceeds ``Options/messageAttributeLimit``)
    /// - A body exceeds ``Options/bodySizeLimit``
    /// - The response violates IMAP syntax
    /// - UTF-8 validation fails
    ///
    /// - Parameter buffer: A `ByteBuffer` with incoming server data. The parser consumes
    ///   bytes from the front as it parses them.
    ///
    /// - Returns: A ``ResponseOrContinuationRequest`` if a complete response element is parsed,
    ///   or `nil` if more data is needed.
    ///
    /// - Throws: ``ParserError`` for syntax errors, ``ExceededMaximumMessageAttributesError``
    ///   for attribute limit violations, ``ExceededMaximumBodySizeError`` for body size violations,
    ///   ``TooMuchRecursion`` for overly nested structures.
    ///
    /// - SeeAlso: ``ResponseOrContinuationRequest``, ``Options``,
    ///   [RFC 3501 Section 7](https://datatracker.ietf.org/doc/html/rfc3501#section-7)
    public mutating func parseResponseStream(
        buffer inputBytes: inout ByteBuffer
    ) throws -> ResponseOrContinuationRequest? {
        let tracker = StackTracker.makeNewDefault
        var parseBuffer = ParseBuffer(inputBytes)
        defer {
            assert(
                inputBytes.readableBytes >= parseBuffer.readableBytes,
                "illegal state, parse buffer has more remaining than input had: \(inputBytes), \(parseBuffer)"
            )

            // Discard everything that has been parsed off.
            inputBytes.moveReaderIndex(forwardBy: inputBytes.readableBytes - parseBuffer.readableBytes)
        }
        do {
            switch self.mode {
            case .response(let state):
                return try self.parseResponse(state: state, buffer: &parseBuffer, tracker: tracker)
            case .attributeBytes(let remaining, attributeCount: let attributeCount):
                return .response(
                    try self.parseBytes(
                        buffer: &parseBuffer,
                        tracker: tracker,
                        remaining: remaining,
                        attributeCount: attributeCount
                    )
                )
            case .streamingQuoted(attributeCount: let attributeCount):
                return .response(try self.parseQuotedBytes(buffer: &parseBuffer, attributeCount: attributeCount))
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
    private mutating func parseResponse(
        state: ResponseState,
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ResponseOrContinuationRequest {
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
                    parseResponse_fetch,
                    parseResponse_normal,
                    buffer: &buffer,
                    tracker: tracker
                )
                switch response {
                case .fetchResponse(.start(let num)):
                    self.moveStateMachine(
                        expected: .response(.fetchOrNormal),
                        next: .response(.fetchMiddle(attributeCount: 0))
                    )
                    return .response(.fetch(.start(num)))
                case .fetchResponse(.startUID(let num)):
                    self.moveStateMachine(
                        expected: .response(.fetchOrNormal),
                        next: .response(.fetchMiddle(attributeCount: 0))
                    )
                    return .response(.fetch(.startUID(num)))
                case .fetchResponse(.literalStreamingBegin(kind: let kind, byteCount: let size)):
                    try self.guardStreamingSizeLimit(size: size)
                    let attributeCount = try self.guardFetchMiddleAttributeCount()
                    self.moveStateMachine(
                        expected: .response(.fetchMiddle(attributeCount: attributeCount)),
                        next: .attributeBytes(size, attributeCount: attributeCount + 1)
                    )
                    return .response(.fetch(.streamingBegin(kind: kind, byteCount: size)))

                case .fetchResponse(.quotedStreamingBegin(kind: let kind, byteCount: let size)):
                    try self.guardStreamingSizeLimit(size: size)
                    let attributeCount = try self.guardFetchMiddleAttributeCount()
                    self.moveStateMachine(
                        expected: .response(.fetchMiddle(attributeCount: attributeCount)),
                        next: .streamingQuoted(attributeCount: attributeCount + 1)
                    )
                    return .response(.fetch(.streamingBegin(kind: kind, byteCount: size)))

                case .fetchResponse(.finish):
                    let attributeCount = try self.guardFetchMiddleAttributeCount()
                    self.moveStateMachine(
                        expected: .response(.fetchMiddle(attributeCount: attributeCount)),
                        next: .response(.fetchOrNormal)
                    )
                    return .response(.fetch(.finish))

                case .untaggedResponse(let payload):
                    return .response(.untagged(payload))

                case .fetchResponse(.simpleAttribute(let att)):
                    let attributeCount = try self.guardFetchMiddleAttributeCount()
                    self.moveStateMachine(
                        expected: .response(.fetchMiddle(attributeCount: attributeCount)),
                        next: .response(.fetchMiddle(attributeCount: attributeCount + 1))
                    )
                    return .response(.fetch(.simpleAttribute(att)))
                }
            } catch is ParserError {
                return try self._parseResponse(buffer: &buffer, tracker: tracker)
            }
        }
    }

    /// Validates that the attribute count is within the allowed limit, and returns it.
    private func guardFetchMiddleAttributeCount() throws -> Int {
        guard case .response(.fetchMiddle(attributeCount: let attributeCount)) = self.mode else {
            preconditionFailure("We should be in fetch middle: \(self.mode)")
        }
        guard attributeCount < self.messageAttributeLimit else {
            throw ExceededMaximumMessageAttributesError(
                actualCount: attributeCount,
                maximumCount: self.messageAttributeLimit
            )
        }
        return attributeCount
    }

    private func guardStreamingSizeLimit(size: Int) throws {
        guard size < self.bodySizeLimit else {
            throw ExceededMaximumBodySizeError(
                actualCount: UInt64(exactly: size) ?? 0,
                maximumCount: self.bodySizeLimit
            )
        }
    }

    private func _parseResponse(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ResponseOrContinuationRequest {
        func parseResponse_continuation(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ResponseOrContinuationRequest {
            .continuationRequest(try self.parser.parseContinuationRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> ResponseOrContinuationRequest {
            .response(.tagged(try self.parser.parseTaggedResponse(buffer: &buffer, tracker: tracker)))
        }

        return try PL.parseOneOf(
            [
                parseResponse_continuation,
                parseResponse_tagged,
            ],
            buffer: &buffer,
            tracker: tracker
        )
    }
}

// MARK: - Parse bytes

extension ResponseParser {
    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    private mutating func parseBytes(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        remaining: Int,
        attributeCount: Int
    ) throws -> Response {
        guard remaining == 0 else {
            let bytes = try PL.parseBytes(
                buffer: &buffer,
                tracker: .makeNewDefault,
                upTo: remaining
            )
            let leftToRead = remaining - bytes.readableBytes
            assert(leftToRead >= 0, "\(leftToRead) is negative")

            return self.moveStateMachine(
                expected: .attributeBytes(remaining, attributeCount: attributeCount),
                next: .attributeBytes(leftToRead, attributeCount: attributeCount),
                returnValue: .fetch(.streamingBytes(bytes))
            )
        }
        return self.moveStateMachine(
            expected: .attributeBytes(remaining, attributeCount: attributeCount),
            // we've finished parsing an attribute here so increment the count
            next: .response(.fetchMiddle(attributeCount: attributeCount + 1)),
            returnValue: .fetch(.streamingEnd)
        )
    }

    private mutating func parseQuotedBytes(buffer: inout ParseBuffer, attributeCount: Int) throws -> Response {
        let quoted = try self.parser.parseQuoted(buffer: &buffer, tracker: .makeNewDefault)
        return self.moveStateMachine(
            expected: .streamingQuoted(attributeCount: attributeCount),
            next: .attributeBytes(0, attributeCount: attributeCount),
            returnValue: .fetch(.streamingBytes(quoted))
        )
    }
}
