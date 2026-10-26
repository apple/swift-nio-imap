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

/// A command stream part with synchronizing literal information.
///
/// When parsing client commands, the parser must handle synchronizing literals (RFC 3501 Section 4.3).
/// With synchronizing literals, the client sends the literal size, waits for a `+` continuation,
/// then sends the literal data. This struct wraps a ``CommandStreamPart`` with metadata about
/// how many synchronizing literals it contains.
///
/// When ``numberOfSynchronisingLiterals`` is greater than 0, the parser expects the server
/// to send that many `+` continuation requests before this command is complete.
///
/// - SeeAlso: ``CommandStreamPart``, [RFC 3501 Section 4.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3.3)
public struct SynchronizedCommand: Hashable, Sendable {
    /// The number of synchronising literals contained in the corresponding command.
    ///
    /// When this is greater than 0, the server must send that many continuation
    /// requests (`+` responses) to allow the client to send each literal's data.
    /// Each synchronizing literal (format `{size}`) requires a `+` response before
    /// the literal data is sent.
    public var numberOfSynchronisingLiterals: Int

    /// A command to be sent to a server.
    ///
    /// The actual ``CommandStreamPart`` (or part of a command in streaming mode).
    /// May be `nil` if only continuation data is being sent.
    public var commandPart: CommandStreamPart?

    /// Creates a new `SynchronizedCommand`.
    ///
    /// - Parameters:
    ///   - commandPart: A ``CommandStreamPart``, if any. Defaults to `nil`.
    ///   - numberOfSynchronisingLiterals: How many synchronising literals are in the command.
    ///     Defaults to 0.
    public init(_ commandPart: CommandStreamPart? = nil, numberOfSynchronisingLiterals: Int = 0) {
        self.commandPart = commandPart
        self.numberOfSynchronisingLiterals = numberOfSynchronisingLiterals
    }
}

/// A parser for IMAP commands sent from a client to a server.
///
/// `CommandParser` incrementally parses the stream of bytes sent by an IMAP client,
/// converting them into ``CommandStreamPart`` structures that represent complete commands
/// or parts of commands (in the case of streaming operations like `APPEND` or `CATENATE`).
///
/// The parser handles:
/// - Regular commands (``Command``)
/// - Streaming commands (`APPEND` with literal data)
/// - Multi-part commands (`CATENATE`)
/// - IDLE command lifecycle
/// - Synchronizing literals (RFC 3501 Section 4.3) where the server sends `+` before literal data
///
/// The parser maintains internal state to track incomplete parsing operations and can process
/// incomplete input, returning `nil` until enough bytes are available for a complete element.
///
/// The parser expects correctly framed input, such as `FramingParser` provides. For example,
/// it doesn't skip an LF orphaned by a CRLF split across reads.
///
/// ## Usage
///
/// ```swift
/// var parser = CommandParser()
/// var buffer = IMAPInputBuffer()
/// buffer.append(bytesFromTheNetwork)
/// while let syncedCommand = try parser.parseCommandStream(buffer: &buffer) {
///     if syncedCommand.numberOfSynchronisingLiterals > 0 {
///         // Wait for continuation requests and responses
///     }
///     if let part = syncedCommand.commandPart {
///         // Process the command
///     }
/// }
/// ```
///
/// - SeeAlso: ``SynchronizedCommand``, ``CommandStreamPart``,
///   [RFC 3501 Section 5](https://datatracker.ietf.org/doc/html/rfc3501#section-5) (commands)
public struct CommandParser: Parser, Sendable {
    enum Mode: Hashable, Sendable {
        case lines
        case idle
        /// An `AUTHENTICATE` command has been parsed and we expect either the client's base64
        /// challenge response(s) or the next ordinary command once authentication completes.
        case expectingAuthenticationResponse
        case waitingForMessage
        case streamingBytes(Int)
        case streamingEnd
        case waitingForCatenatePart(seenPreviousPart: Bool)
        case streamingCatenateBytes(Int)
        case streamingCatenateEnd

        var isStreamingAppend: Bool {
            guard case .streamingBytes = self else {
                return false
            }
            return true
        }
    }

    /// The context in which a command line is being parsed, controlling which inputs
    /// ``parseCommandOrAppend(in:buffer:tracker:)`` accepts in addition to tagged commands
    /// and `APPEND`.
    private enum CommandLineContext {
        /// Ordinary command parsing (corresponds to `Mode.lines`). Only tagged commands and
        /// `APPEND` are valid; a bare CRLF or an unsolicited base64 line is a parse error.
        case standard
        /// An `AUTHENTICATE` exchange is in progress (corresponds to
        /// `Mode.expectingAuthenticationResponse`), so a base64 challenge response is additionally
        /// accepted — e.g. for multi-round SASL mechanisms such as `GSSAPI`.
        case authenticating
    }

    let parser: GrammarParser

    /// The maximum number of bytes that can be buffered at any time.
    ///
    /// When the parser accumulates more than this limit, an error is thrown.
    /// Serves as DoS protection against malicious or malformed input.
    /// Defaults to ``IMAPDefaults/lineLengthLimit`` (8192 bytes).
    public let bufferLimit: Int

    /// The maximum size of a single literal (data between `{size}` markers).
    ///
    /// Serves as DoS protection against excessively large literal data.
    /// Defaults to ``IMAPDefaults/literalSizeLimit`` (4096 bytes).
    public var literalSizeLimit: Int { parser.literalSizeLimit }
    private(set) var mode: Mode = .lines
    private var synchronisingLiteralParser = SynchronizingLiteralParser()

    /// Creates a new `CommandParser` with configurable buffer limits.
    ///
    /// The buffer limits serve as DoS protection, preventing malicious or malformed input
    /// from consuming excessive memory or processing time.
    ///
    /// - Parameters:
    ///   - bufferLimit: The maximum number of bytes that can be buffered at any time.
    ///     If the parser accumulates more than this, an error is thrown. Defaults to
    ///     ``IMAPDefaults/lineLengthLimit`` (8192 bytes).
    ///   - literalSizeLimit: The maximum size of a single literal (data between `{size}` markers).
    ///     Defaults to ``IMAPDefaults/literalSizeLimit`` (4096 bytes).
    ///
    /// - Throws: Errors during parsing if limits are exceeded or parsing fails.
    ///
    /// - SeeAlso: ``parseCommandStream(buffer:)``
    public init(bufferLimit: Int = IMAPDefaults.lineLengthLimit, literalSizeLimit: Int = IMAPDefaults.literalSizeLimit)
    {
        self.bufferLimit = bufferLimit
        self.parser = GrammarParser(literalSizeLimit: literalSizeLimit)
    }

    /// Parses incoming bytes into command stream parts.
    ///
    /// Incrementally consumes bytes from the buffer and returns parsed command parts.
    /// The parser maintains state across calls, so a command may arrive in multiple
    /// reads. The input must be correctly framed, for example by `FramingParser`: a CRLF
    /// split across reads is not supported.
    ///
    /// Returns `nil` when more data is needed. Throws an error if:
    /// - The buffer exceeds ``bufferLimit``
    /// - A literal exceeds ``literalSizeLimit``
    /// - The input violates IMAP command syntax
    /// - UTF-8 validation fails
    ///
    /// - Parameter buffer: The received bytes. Whatever the parser consumes is discarded from the
    ///   front, so the same buffer is passed again as more arrives. An ``IMAPInputBuffer`` is what a
    ///   connection should hand over: it keeps each read where it landed, and it is the only input an
    ///   `APPEND` payload can be delivered out of without being copied.
    ///
    /// - Returns: A ``SynchronizedCommand`` if a complete element is parsed, or `nil`
    ///   if more data is needed.
    ///
    /// - Throws: ``ParserError`` for syntax errors, ``BadCommand`` for tagged command
    ///   parse failures, ``TooMuchRecursion`` for overly nested structures.
    ///
    /// - SeeAlso: ``SynchronizedCommand``, [RFC 3501 Section 5](https://datatracker.ietf.org/doc/html/rfc3501#section-5)
    public mutating func parseCommandStream<Input: ConsumableParserInputBuffer>(
        buffer: inout Input
    ) throws -> SynchronizedCommand? {
        guard buffer.count > 0 else {
            return nil
        }

        // Both passes below share one gather. Framing has to run first — it decides how much of what
        // has arrived may be parsed at all — and it consumes nothing, so the cursor it hands back is
        // still at the read position.
        var framingResult: SynchronizingLiteralParser.FramingResult?
        var consumedBytes = 0
        let command: CommandStreamPart?
        do {
            command = try buffer.withParseInput(limit: .max) { input in
                let framing = try self.synchronisingLiteralParser.parseContinuationsNecessary(input)
                framingResult = framing
                // `narrowLimit` is what keeps the parser from seeing past what the framing pass deemed
                // valid. It used to be a `getSlice` of exactly those bytes, which the cursor makes
                // unnecessary: bytes past the limit are invisible to every primitive.
                input.narrowLimit(toNext: framing.maximumValidBytes)
                defer { consumedBytes = input.consumed }
                return try self.parseCommandStream0(buffer: &input, tracker: .makeNewDefault)
            }
        } catch is IncompleteMessage {
            command = nil
        }

        // Framing ran before anything could throw `IncompleteMessage`, so its literal count is known
        // even when no command came out of this call.
        guard let framingResult else {
            preconditionFailure("framing did not run")
        }

        guard let command else {
            assert(
                consumedBytes == 0,
                "parser consumed \(consumedBytes) bytes on nil, out of \(framingResult.maximumValidBytes)"
            )
            guard framingResult.synchronizingLiteralCount > 0 else { return nil }
            return SynchronizedCommand(numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
        }

        assert(consumedBytes >= 0, "allegedly, we consumed a negative amount of bytes: \(consumedBytes)")
        assert(
            consumedBytes <= framingResult.maximumValidBytes,
            "We consumed \(consumedBytes) which is more than the framing parser thought are maximally "
                + "valid: \(framingResult), \(self.synchronisingLiteralParser)"
        )
        // Only now are the bytes gone from the caller's buffer: a call that produced nothing consumes
        // nothing, so the same bytes are parsed again once the rest of the command arrives.
        buffer.discardFirst(consumedBytes)
        self.synchronisingLiteralParser.consumed(consumedBytes)
        return SynchronizedCommand(command, numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
    }

    private mutating func parseCommandStream0(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart? {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            switch self.mode {
            case .idle:
                return try self.handleIdle(buffer: &buffer, tracker: tracker)
            case .lines:
                return try self.handleLines(buffer: &buffer, tracker: tracker)
            case .expectingAuthenticationResponse:
                return try self.handleAuthentication(buffer: &buffer, tracker: tracker)
            case .waitingForMessage:
                return try self.handleWaitingForMessage(buffer: &buffer, tracker: tracker)
            case .streamingBytes(let remaining):
                return try self.handleStreamingBytes(buffer: &buffer, tracker: tracker, remaining: remaining)
            case .streamingEnd:
                return try self.handleStreamingEnd(buffer: &buffer, tracker: tracker)
            case .waitingForCatenatePart(seenPreviousPart: let seenPreviousPart):
                return try self.handleCatenatePart(
                    expectPrecedingSpace: seenPreviousPart,
                    buffer: &buffer,
                    tracker: tracker
                )
            case .streamingCatenateBytes(let remaining):
                return try self.handleStreamingCatenateBytes(buffer: &buffer, tracker: tracker, remaining: remaining)
            case .streamingCatenateEnd:
                return try self.handleStreamingCatenateEnd(buffer: &buffer, tracker: tracker)
            }
        }
    }

    private mutating func handleStreamingBytes(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        remaining: Int
    ) throws -> CommandStreamPart {
        assert(self.mode.isStreamingAppend)
        let bytes = try buffer.extractBuffer(upTo: remaining)

        assert(bytes.count <= remaining)
        if bytes.count == remaining {
            self.mode = .streamingEnd
        } else {
            self.mode = .streamingBytes(remaining - bytes.count)
        }
        return .append(.messageBytes(bytes))
    }

    private mutating func handleLines(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
        // In `.lines` mode there is no `AUTHENTICATE` in progress, so a bare CRLF / unsolicited
        // base64 line must be rejected rather than misclassified as a continuation response.
        try self.parseCommandOrAppend(in: .standard, buffer: &buffer, tracker: tracker)
    }

    /// Parses while an `AUTHENTICATE` exchange is in progress.
    ///
    /// In addition to ordinary commands and `APPEND`, the client may send one or more base64
    /// challenge responses (multi-round SASL, e.g. `GSSAPI`). The parser leaves this mode only
    /// once an ordinary command or `APPEND` is parsed, since it never sees the server's tagged
    /// completion response.
    private mutating func handleAuthentication(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        try self.parseCommandOrAppend(in: .authenticating, buffer: &buffer, tracker: tracker)
    }

    /// Shared implementation for `.lines` and `.expectingAuthenticationResponse` modes.
    ///
    /// Both contexts accept a tagged command or an `APPEND`; only `.authenticating` additionally
    /// accepts a base64 continuation response. `parseCommand` is tried first and a tagged command
    /// requires `tag SP …` while a base64 line contains no space, so there is no ambiguity between
    /// the two.
    private mutating func parseCommandOrAppend(
        in context: CommandLineContext,
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        func parseCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
            let command = try self.parser.parseTaggedCommand(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            switch command.command {
            case .idleStart:
                self.mode = .idle
            case .authenticate:
                // Expect the client's base64 challenge response(s) until authentication completes.
                self.mode = .expectingAuthenticationResponse
            default:
                // Any other command exits a preceding `AUTHENTICATE` exchange. This is a harmless
                // no-op when we are already in `.lines`.
                self.mode = .lines
            }
            return .tagged(command)
        }

        func parseAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
            let appendCommand = try self.parser.parseAppend(buffer: &buffer, tracker: tracker)
            self.mode = .waitingForMessage
            return appendCommand
        }

        func parseAuthenticationChallengeResponse(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> CommandStreamPart {
            let authenticationChallengeResponse = try self.parser.parseBase64(buffer: &buffer, tracker: tracker)
            try buffer.matchNewline()
            // Stay in `.expectingAuthenticationResponse` to support multi-round SASL exchanges.
            // A bounded base64 blob, so this owns its bytes outright rather than pinning the input.
            return .continuationResponse(IMAPBuffer(authenticationChallengeResponse))
        }

        switch context {
        case .standard:
            return try buffer.parseOneOf(
                { try parseCommand(buffer: &$0, tracker: $1) },
                { try parseAppend(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        case .authenticating:
            return try buffer.parseOneOf(
                { try parseCommand(buffer: &$0, tracker: $1) },
                { try parseAppend(buffer: &$0, tracker: $1) },
                { try parseAuthenticationChallengeResponse(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }
    }

    private mutating func handleWaitingForMessage(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        do {
            let command = try self.parser.parseAppendOrCatenateMessage(buffer: &buffer, tracker: tracker)

            switch command {
            case .append(let message):
                self.mode = .streamingBytes(message.data.byteCount)
                return .append(.beginMessage(message: message))
            case .catenate(let options):
                self.mode = .waitingForCatenatePart(seenPreviousPart: false)
                return .append(.beginCatenate(options: options))
            }
        } catch is ParserError {
            let save = buffer
            do {
                try buffer.matchNewline()
                self.mode = .lines
                return .append(.finish)
            } catch {
                buffer = save
                throw error
            }
        }
    }

    private mutating func handleStreamingEnd(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        self.mode = .waitingForMessage
        return .append(.endMessage)
    }

    private mutating func handleIdle(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
        try self.parser.parseIdleDone(buffer: &buffer, tracker: tracker)
        self.mode = .lines
        return .idleDone
    }

    private mutating func handleCatenatePart(
        expectPrecedingSpace: Bool,
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        let result = try self.parser.parseCatenatePart(
            expectPrecedingSpace: expectPrecedingSpace,
            buffer: &buffer,
            tracker: tracker
        )
        switch result {
        case .url(let url):
            self.mode = .waitingForCatenatePart(seenPreviousPart: true)
            return .append(.catenateURL(url))
        case .text(let length):
            self.mode = .streamingCatenateBytes(length)
            return .append(.catenateData(.begin(size: length)))
        case .end:
            self.mode = .waitingForMessage
            return .append(.endCatenate)
        }
    }

    private mutating func handleStreamingCatenateBytes(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        remaining: Int
    ) throws -> CommandStreamPart {
        let bytes = try buffer.extractBuffer(upTo: remaining)

        assert(bytes.count <= remaining)
        if bytes.count == remaining {
            self.mode = .streamingCatenateEnd
        } else {
            self.mode = .streamingCatenateBytes(remaining - bytes.count)
        }

        return .append(.catenateData(.bytes(bytes)))
    }

    private mutating func handleStreamingCatenateEnd(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart {
        self.mode = .waitingForCatenatePart(seenPreviousPart: true)
        return .append(.catenateData(.end))
    }
}
