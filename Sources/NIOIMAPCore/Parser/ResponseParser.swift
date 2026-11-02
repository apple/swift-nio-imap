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
/// Server responses can include large message bodies (for example, in FETCH responses).
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
/// var buffer = IMAPInputBuffer()
/// buffer.append(bytesFromTheNetwork)
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
        /// many repeated strings (for example, flag names). Defaults to `nil` (no caching).
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
    /// Newline kind of the last successfully parsed response.
    private var lastResponseNewlineEnding: ParseInput.Newline?

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
        self.lastResponseNewlineEnding = nil
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
    /// - Parameter inputBytes: The received bytes. Whatever the parser consumes is discarded from the
    ///   front, so the same buffer is passed again as more arrives. An ``IMAPInputBuffer`` is what a
    ///   connection should hand over: it keeps each read where it landed, and it is the only input a
    ///   large literal can be delivered out of without being copied.
    ///
    /// - Returns: A ``ResponseOrContinuationRequest`` if a complete response element is parsed,
    ///   or `nil` if more data is needed.
    ///
    /// - Throws: ``ParserError`` for syntax errors, ``ExceededMaximumMessageAttributesError``
    ///   for attribute limit violations, ``ExceededMaximumBodySizeError`` for body size violations,
    ///   ``TooMuchRecursion`` for overly nested structures, ``NoForwardProgress`` if parsing stopped
    ///   consuming input.
    ///
    /// - Important: `.fetch(.streamingEnd)` consumes no bytes, and is never followed by another result
    ///   that does not. A caller driving this in its own loop, rather than through `IMAPClientHandler`,
    ///   should stop when results keep coming without the buffer shrinking: that is what
    ///   `IMAPClientHandler` does, and it is the guard against a parser bug spinning forever.
    ///
    /// - SeeAlso: ``ResponseOrContinuationRequest``, ``Options``,
    ///   [RFC 3501 Section 7](https://datatracker.ietf.org/doc/html/rfc3501#section-7)
    public mutating func parseResponseStream<Input: ConsumableParserInputBuffer>(
        buffer inputBytes: inout Input
    ) throws -> ResponseOrContinuationRequest? {
        let tracker = StackTracker.makeNewDefault
        // Whatever the parser consumed is discarded on *every* exit path, a throw included, which is
        // what `parse` does: the streaming modes legitimately make progress and then report that they
        // need more bytes, and `skipLF` below consumes a byte outside any backtracking scope.
        return try inputBytes.parse { input in
            // Incomplete input is handled here, unboxed; anything else leaves as its public error type.
            do throws(ParseFailure) {
                switch self.mode {
                case .response(let state):
                    // Handle orphaned CR/LF from split CRLF where previous buffer ended with CR-only:
                    if self.lastResponseNewlineEnding == .cr, input.skipLF() {
                        // Did consume complete CR-LF pair:
                        self.lastResponseNewlineEnding = .crlf
                    }

                    let result = try self.parseResponseAndNewline(
                        state: state,
                        buffer: &input,
                        tracker: tracker
                    )
                    self.lastResponseNewlineEnding = result.newline
                    return result.response
                case .attributeBytes(let remaining, attributeCount: let attributeCount):
                    // Handle orphaned LF from a literal header's CRLF split across buffers. Only the
                    // first byte after the header can be that LF. Any other is part of the literal.
                    if self.lastResponseNewlineEnding == .cr, !input.isEmpty {
                        input.skipLF()
                        self.lastResponseNewlineEnding = nil
                    }
                    return .response(
                        try self.parseBytes(
                            buffer: &input,
                            tracker: tracker,
                            remaining: remaining,
                            attributeCount: attributeCount
                        )
                    )
                case .streamingQuoted(attributeCount: let attributeCount):
                    return .response(try self.parseQuotedBytes(buffer: &input, attributeCount: attributeCount))
                }
            } catch .incomplete {
                return nil
            } catch {
                throw error.unwrapped
            }
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
    struct ResponseAndNewline {
        var response: ResponseOrContinuationRequest
        var newline: ParseInput.Newline?
    }

    private mutating func parseResponseAndNewline(
        state: ResponseState,
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ResponseAndNewline {
        let response = try parseResponse(
            state: state,
            buffer: &buffer,
            tracker: tracker
        )
        return ResponseAndNewline(
            response: response,
            newline: buffer.terminatingNewline
        )
    }

    private mutating func parseResponse(
        state: ResponseState,
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ResponseOrContinuationRequest {
        enum _Response: Hashable {
            case untaggedResponse(ResponsePayload)
            case fetchResponse(GrammarParser._FetchResponse)
        }

        func parseResponse_fetch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> _Response {
            switch state {
            case .fetchOrNormal:
                return .fetchResponse(try self.parser.parseFetchResponseStart(buffer: &buffer, tracker: tracker))
            case .fetchMiddle:
                return .fetchResponse(try self.parser.parseFetchResponse(buffer: &buffer, tracker: tracker))
            }
        }

        func parseResponse_normal(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> _Response {
            let response = try self.parser.parseResponseData(buffer: &buffer, tracker: tracker)
            return .untaggedResponse(response)
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            // Spaces are optional; incomplete still propagates.
            do throws(ParseFailure) { try buffer.parseSpaces() } catch .mismatch {}
            do throws(ParseFailure) {
                let response = try buffer.parseOneOf(
                    { b, t throws(ParseFailure) in try parseResponse_fetch(buffer: &b, tracker: t) },
                    { b, t throws(ParseFailure) in try parseResponse_normal(buffer: &b, tracker: t) },
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
            } catch .mismatch {
                return try self._parseResponse(buffer: &buffer, tracker: tracker)
            }
        }
    }

    /// Validates that the attribute count is within the allowed limit, and returns it.
    private func guardFetchMiddleAttributeCount() throws(ParseFailure) -> Int {
        guard case .response(.fetchMiddle(attributeCount: let attributeCount)) = self.mode else {
            preconditionFailure("We should be in fetch middle: \(self.mode)")
        }
        guard attributeCount < self.messageAttributeLimit else {
            throw .messageAttributesExceeded(
                ExceededMaximumMessageAttributesError(
                    actualCount: attributeCount,
                    maximumCount: self.messageAttributeLimit
                )
            )
        }
        return attributeCount
    }

    private func guardStreamingSizeLimit(size: Int) throws(ParseFailure) {
        guard size < self.bodySizeLimit else {
            throw .bodySizeExceeded(
                ExceededMaximumBodySizeError(
                    actualCount: UInt64(exactly: size) ?? 0,
                    maximumCount: self.bodySizeLimit
                )
            )
        }
    }

    private func _parseResponse(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ResponseOrContinuationRequest {
        func parseResponse_continuation(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ResponseOrContinuationRequest {
            .continuationRequest(try self.parser.parseContinuationRequest(buffer: &buffer, tracker: tracker))
        }

        func parseResponse_tagged(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> ResponseOrContinuationRequest {
            .response(.tagged(try self.parser.parseTaggedResponse(buffer: &buffer, tracker: tracker)))
        }

        let continuation = ParseAlternative<ResponseOrContinuationRequest> { b, t throws(ParseFailure) in
            try parseResponse_continuation(buffer: &b, tracker: t)
        }
        let tagged = ParseAlternative<ResponseOrContinuationRequest> { b, t throws(ParseFailure) in
            try parseResponse_tagged(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([continuation, tagged], tracker: tracker)
    }
}

// MARK: - Parse bytes

extension ResponseParser {
    /// Extracts the next run of a streamed literal. If more bytes are present than are required only
    /// those that are required are extracted, and if fewer have arrived then what there is comes back
    /// and the rest follows on a later call.
    /// - parameter buffer: The cursor from which bytes should be extracted.
    /// - returns: A `.streamingBytes` response carrying the extracted run, or `.streamingEnd`.
    private mutating func parseBytes(
        buffer: inout ParseInput,
        tracker: StackTracker,
        remaining: Int,
        attributeCount: Int
    ) throws(ParseFailure) -> Response {
        guard remaining == 0 else {
            let bytes = try buffer.extractBuffer(
                upTo: remaining
            )
            let leftToRead = remaining - bytes.count
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

    private mutating func parseQuotedBytes(
        buffer: inout ParseInput,
        attributeCount: Int
    ) throws(ParseFailure) -> Response {
        let quoted = try self.parser.parseQuoted(buffer: &buffer, tracker: .makeNewDefault)
        return self.moveStateMachine(
            expected: .streamingQuoted(attributeCount: attributeCount),
            next: .attributeBytes(0, attributeCount: attributeCount),
            // `parseQuoted` unescapes into a fresh array when the string contains escapes, and it is
            // bounded by `lineLengthLimit` either way, so these bytes are owned rather than referenced.
            returnValue: .fetch(.streamingBytes(IMAPBuffer(quoted)))
        )
    }
}
