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

public struct CommandParser: Parser {
    enum Mode: Equatable {
        case lines
        case idle
        case streamingAppend(Int)
        case streamingEnd

        var isStreamingAppend: Bool {
            if case .streamingAppend = self {
                return true
            } else {
                return false
            }
        }
    }

    let bufferLimit: Int
    private(set) var mode: Mode = .lines

    public init(bufferLimit: Int = 1_000) {
        self.bufferLimit = bufferLimit
    }

    /// Parses a given `ByteBuffer` into a `CommandStream` that may then be transmitted.
    /// Parsing depends on the current mode of the parser.
    /// - parameter buffer: A `ByteBuffer` that will be consumed for parsing.
    /// - returns: A `CommandStream` that can be sent.
    public mutating func parseCommandStream(buffer: inout ByteBuffer) throws -> CommandStream? {
        // TODO: SynchronisingLiteralParser should be added here but currently we don't have a place to return
        // the necessary continuations.
        do {
            return try self.parseCommandStream0(buffer: &buffer, tracker: .makeNewDefaultLimitStackTracker)
        } catch is _IncompleteMessage {
            return nil
        }
    }

    private mutating func parseCommandStream0(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CommandStream? {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            switch self.mode {
            case .streamingAppend(let remaining):
                let bytes = self.parseBytes(buffer: &buffer, remaining: remaining)
                return .bytes(bytes)
            case .streamingEnd:
                try GrammarParser.parseCommandEnd(buffer: &buffer, tracker: tracker)
                do {
                    self.mode = .lines
                    return try self.parseCommandStream0(buffer: &buffer, tracker: tracker)
                } catch {
                    self.mode = .streamingEnd
                    throw error
                }
            case .idle:
                try GrammarParser.parseIdleDone(buffer: &buffer, tracker: tracker)
                self.mode = .lines
                return .idleDone
            case .lines:
                let save = buffer
                do {
                    let command = try self.parseCommand(buffer: &buffer, tracker: tracker)
                    if case .append(to: _, firstMessageMetadata: let firstMetdata) = command.command {
                        self.mode = .streamingAppend(firstMetdata.data.byteCount)
                    } else {
                        try GrammarParser.parseCommandEnd(buffer: &buffer, tracker: tracker)
                    }
                    if case .idleStart = command.command {
                        self.mode = .idle
                    }
                    return .command(command)
                } catch {
                    buffer = save
                    throw error
                }
            }
        }
    }

    /// Extracts bytes from a given `ByteBuffer`. If more bytes are present than are required
    /// only those that are required will be extracted. If not enough bytes are provided then the given
    /// `ByteBuffer` will be emptied.
    /// - parameter buffer: The buffer from which bytes should be extracted.
    /// - returns: A new `ByteBuffer` containing extracted bytes.
    private mutating func parseBytes(buffer: inout ByteBuffer, remaining: Int) -> ByteBuffer {
        assert(self.mode.isStreamingAppend)
        if buffer.readableBytes >= remaining {
            self.mode = .streamingEnd
            return buffer.readSlice(length: remaining)!
        }

        let bytes = buffer.readSlice(length: buffer.readableBytes)!
        self.mode = .streamingAppend(remaining - bytes.readableBytes)
        return bytes
    }

    /// Attempts to parse a given `ByteBuffer` into a `ClientCommand`
    /// Note that the `ByteBuffer` argument is consumable. If parsing fails
    /// then a portion of the buffer may still have been consumed. It is
    /// recommended that you maintain your own copy.
    /// Upon failure a `PublicParserError` will be thrown.
    /// - parameter buffer: The consumable buffer to parse.
    /// - returns: A `ClientCommand` if parsing was successful.
    private mutating func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try self.throwIfExceededBufferLimit(&buffer)
        do {
            return try GrammarParser.parseCommand(buffer: &buffer, tracker: tracker)
        } catch is ParsingError {
            throw _IncompleteMessage()
        }
    }
}
