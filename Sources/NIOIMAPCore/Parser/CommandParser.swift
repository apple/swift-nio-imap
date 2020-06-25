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

public struct PartialCommandStream: Equatable {
    public var numberOfSynchronisingLiterals: Int
    public var command: CommandStream?

    internal init(numberOfSynchronisingLiterals: Int, command: CommandStream?) {
        self.numberOfSynchronisingLiterals = numberOfSynchronisingLiterals
        self.command = command
    }

    public init(_ command: CommandStream, numberOfSynchronisingLiterals: Int = 0) {
        self = .init(numberOfSynchronisingLiterals: numberOfSynchronisingLiterals, command: command)
    }

    public init(numberOfSynchronisingLiterals: Int) {
        self = .init(numberOfSynchronisingLiterals: numberOfSynchronisingLiterals, command: nil)
    }
}

public struct CommandParser: Parser {
    enum Mode: Equatable {
        case lines
        case idle
        case waitingForMessage
        case streamingBytes(Int)
        case streamingEnd

        var isStreamingAppend: Bool {
            if case .streamingBytes = self {
                return true
            } else {
                return false
            }
        }
    }

    let bufferLimit: Int
    private(set) var mode: Mode = .lines
    private var synchronisingLiteralParser = SynchronizingLiteralParser()

    public init(bufferLimit: Int = 1_000) {
        self.bufferLimit = bufferLimit
    }

    /// Parses a given `ByteBuffer` into a `CommandStream` that may then be transmitted.
    /// Parsing depends on the current mode of the parser.
    /// - parameter buffer: A `ByteBuffer` that will be consumed for parsing.
    /// - returns: A `CommandStream` that can be sent.
    public mutating func parseCommandStream(buffer: inout ByteBuffer) throws -> PartialCommandStream? {
        let save = buffer
        let framingResult = try self.synchronisingLiteralParser.parseContinuationsNecessary(buffer)
        var actuallyVisible = buffer.getSlice(at: buffer.readerIndex, length: framingResult.maximumValidBytes)!
        
        func parseCommand() throws -> CommandStream? {
            do {
                if let command = try self.parseCommandStream0(buffer: &actuallyVisible, tracker: .makeNewDefaultLimitStackTracker) {
                    // We need to discard the bytes we consumed from the real buffer.
                    let consumedBytes = framingResult.maximumValidBytes - actuallyVisible.readableBytes
                    buffer.moveReaderIndex(forwardBy: consumedBytes)

                    assert(buffer.writerIndex == save.writerIndex,
                           "the writer index of the buffer moved whilst parsing which is not supported: \(buffer), \(save)")
                    assert(consumedBytes >= 0,
                           "allegedly, we consumed a negative amount of bytes: \(consumedBytes)")
                    self.synchronisingLiteralParser.consumed(consumedBytes)
                    assert(consumedBytes <= framingResult.maximumValidBytes,
                           "We consumed \(consumedBytes) which is more than the framing parser thought are maximally " +
                               "valid: \(framingResult), \(self.synchronisingLiteralParser)")
                    return command
                } else {
                    assert(framingResult.maximumValidBytes == actuallyVisible.readableBytes,
                           "parser consumed bytes on nil: readableBytes before parse: \(framingResult.maximumValidBytes), buffer: \(actuallyVisible)")
                    return nil
                }
            } catch is _IncompleteMessage {
                return nil
            }
        }
        
        if let command = try parseCommand() {
            return PartialCommandStream(command, numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
        } else if framingResult.synchronizingLiteralCount > 0 {
            return PartialCommandStream(numberOfSynchronisingLiterals: framingResult.synchronizingLiteralCount)
        } else {
            return nil
        }
    }

    private mutating func parseCommandStream0(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CommandStream? {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            switch self.mode {
            case .idle:
                try GrammarParser.parseIdleDone(buffer: &buffer, tracker: tracker)
                self.mode = .lines
                return .idleDone
            case .lines:
                let save = buffer
                do {
                    let command = try self.parseCommand(buffer: &buffer, tracker: tracker)
                    try GrammarParser.parseCommandEnd(buffer: &buffer, tracker: tracker)
                    if case .idleStart = command.command {
                        self.mode = .idle
                    }
                    return .command(command)
                } catch is ParserError {
                    buffer = save
                    let appendCommand = try GrammarParser.parseAppend(buffer: &buffer, tracker: tracker)
                    self.mode = .waitingForMessage
                    return appendCommand
                } catch {
                    buffer = save
                    throw error
                }
            case .waitingForMessage:
                do {
                    let message = try GrammarParser.parseAppendMessage(buffer: &buffer, tracker: tracker)
                    self.mode = .streamingBytes(message.data.byteCount)
                    return .append(.beginMessage(messsage: message))
                } catch is ParserError {
                    let save = buffer
                    do {
                        try GrammarParser.parseCommandEnd(buffer: &buffer, tracker: tracker)
                        self.mode = .lines
                        return .append(.finish)
                    } catch {
                        buffer = save
                        throw error
                    }
                }
            case .streamingBytes(let remaining):
                let bytes = self.parseBytes(buffer: &buffer, remaining: remaining)
                return .append(.messageBytes(bytes))
            case .streamingEnd:
                self.mode = .waitingForMessage
                return .append(.endMessage)
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
        self.mode = .streamingBytes(remaining - bytes.readableBytes)
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
        do {
            return try GrammarParser.parseCommand(buffer: &buffer, tracker: tracker)
        } catch is ParsingError {
            throw _IncompleteMessage()
        }
    }

    private mutating func parseAppendCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendCommand {
        fatalError("test")
    }
}
