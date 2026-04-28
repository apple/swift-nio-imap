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
/// ## Usage
///
/// ```swift
/// var parser = CommandParser()
/// var buffer = ByteBuffer(bytes: clientData)
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

    /// Parses a given `ByteBuffer` into command stream parts.
    ///
    /// Incrementally consumes bytes from the buffer and returns parsed command parts.
    /// The parser maintains state across calls, so it can handle commands and data
    /// that arrive in multiple network packets.
    ///
    /// Returns `nil` when more data is needed. Throws an error if:
    /// - The buffer exceeds ``bufferLimit``
    /// - A literal exceeds ``literalSizeLimit``
    /// - The input violates IMAP command syntax
    /// - UTF-8 validation fails
    ///
    /// - Parameter buffer: A `ByteBuffer` with incoming data. The parser consumes
    ///   bytes from the front as it parses them.
    ///
    /// - Returns: A ``SynchronizedCommand`` if a complete element is parsed, or `nil`
    ///   if more data is needed.
    ///
    /// - Throws: ``ParserError`` for syntax errors, ``BadCommand`` for tagged command
    ///   parse failures, ``TooMuchRecursion`` for overly nested structures.
    ///
    /// - SeeAlso: ``SynchronizedCommand``, [RFC 3501 Section 5](https://datatracker.ietf.org/doc/html/rfc3501#section-5)
    public mutating func parseCommandStream(buffer: inout ByteBuffer) throws -> SynchronizedCommand? {
        guard buffer.readableBytes > 0 else {
            return nil
        }

        let save = buffer
        let framingResult = try self.synchronisingLiteralParser.parseContinuationsNecessary(buffer)
        var actuallyVisible = ParseBuffer(
            buffer.getSlice(at: buffer.readerIndex, length: framingResult.maximumValidBytes)!
        )

        func parseCommand() throws -> CommandStreamPart? {
            do {
                guard
                    let command = try self.parseCommandStream0(
                        buffer: &actuallyVisible,
                        tracker: .makeNewDefault
                    )
                else {
                    assert(
                        framingResult.maximumValidBytes == actuallyVisible.readableBytes,
                        "parser consumed bytes on nil: readableBytes before parse: \(framingResult.maximumValidBytes), buffer: \(actuallyVisible)"
                    )
                    return nil
                }
                // We need to discard the bytes we consumed from the real buffer.
                let consumedBytes = framingResult.maximumValidBytes - actuallyVisible.readableBytes
                buffer.moveReaderIndex(forwardBy: consumedBytes)

                assert(
                    buffer.writerIndex == save.writerIndex,
                    "the writer index of the buffer moved whilst parsing which is not supported: \(buffer), \(save)"
                )
                assert(
                    consumedBytes >= 0,
                    "allegedly, we consumed a negative amount of bytes: \(consumedBytes)"
                )
                self.synchronisingLiteralParser.consumed(consumedBytes)
                assert(
                    consumedBytes <= framingResult.maximumValidBytes,
                    "We consumed \(consumedBytes) which is more than the framing parser thought are maximally "
                        + "valid: \(framingResult), \(self.synchronisingLiteralParser)"
                )
                return command
            } catch is IncompleteMessage {
                return nil
            }
        }

        if let command = try parseCommand() {
            return SynchronizedCommand(command, numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
        } else if framingResult.synchronizingLiteralCount > 0 {
            return SynchronizedCommand(numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
        } else {
            return nil
        }
    }

    private mutating func parseCommandStream0(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CommandStreamPart? {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            switch self.mode {
            case .idle:
                return try self.handleIdle(buffer: &buffer, tracker: tracker)
            case .lines:
                return try self.handleLines(buffer: &buffer, tracker: tracker)
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
        let bytes = try PL.parseBytes(buffer: &buffer, tracker: tracker, upTo: remaining)

        assert(bytes.readableBytes <= remaining)
        if bytes.readableBytes == remaining {
            self.mode = .streamingEnd
        } else {
            self.mode = .streamingBytes(remaining - bytes.readableBytes)
        }
        return .append(.messageBytes(bytes))
    }

    private mutating func handleLines(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
        func parseCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
            let command = try self.parser.parseTaggedCommand(buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            if case .idleStart = command.command {
                self.mode = .idle
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
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return .continuationResponse(authenticationChallengeResponse)
        }

        return try PL.parseOneOf(
            parseCommand,
            parseAppend,
            parseAuthenticationChallengeResponse,
            buffer: &buffer,
            tracker: tracker
        )
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
                try PL.parseNewline(buffer: &buffer, tracker: tracker)
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
        let bytes = try PL.parseBytes(buffer: &buffer, tracker: tracker, upTo: remaining)

        assert(bytes.readableBytes <= remaining)
        if bytes.readableBytes == remaining {
            self.mode = .streamingCatenateEnd
        } else {
            self.mode = .streamingCatenateBytes(remaining - bytes.readableBytes)
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
