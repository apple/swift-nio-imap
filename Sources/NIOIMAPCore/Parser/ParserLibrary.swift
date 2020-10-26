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

enum ParserLibrary {}

typealias SubParser<T> = (inout ByteBuffer, StackTracker) throws -> T

public struct ParserError: Error {
    public var hint: String
    var file: String
    var line: Int

    init(hint: String = "Unknown", file: String = (#file), line: Int = #line) {
        self.hint = hint
        self.file = file
        self.line = line
    }
}

/// Signals that a line was too complex and required too many recursive calls.
/// Examine `limit` to see how many stack frames are allowed before this error is thrown.
/// Currently this limit is not able to be modified.
public struct TooMuchRecursion: Error {
    /// The maximum number of recursive calls when parsing data before throwing an error.
    public var limit: Int

    init(limit: Int) {
        self.limit = limit
    }
}

extension ParserLibrary {
    static func parseZeroOrMoreCharacters(buffer: inout ByteBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> String {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw _IncompleteMessage()
            }
            return buffer.readString(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMoreCharacters(buffer: inout ByteBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> String {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw _IncompleteMessage()
            }
            guard firstBad != buffer.readableBytesView.startIndex else {
                throw ParserError(hint: "couldn't find one or more of the required characters")
            }
            return buffer.readString(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseZeroOrMoreCharactersByteBuffer(buffer: inout ByteBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> ByteBuffer {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw _IncompleteMessage()
            }
            return buffer.readSlice(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMoreCharactersByteBuffer(buffer: inout ByteBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> ByteBuffer {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw _IncompleteMessage()
            }
            guard firstBad != buffer.readableBytesView.startIndex else {
                throw ParserError()
            }
            return buffer.readSlice(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMore<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseOneOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseOneOrMore<T>(buffer: inout ByteBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            parsed.append(try parser(&buffer, tracker))
            while let next = try GrammarParser.optional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ByteBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try GrammarParser.optional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseZeroOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseUnsignedInteger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> (number: Int, bytesConsumed: Int) {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
            char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")
        }
        guard let int = Int(string) else {
            throw ParserError(hint: "\(string) is not a number")
        }
        return (int, string.count)
    }

    static func parseUInt64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> (number: UInt64, bytesConsumed: Int) {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
            char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")
        }
        guard let int = UInt64(string) else {
            throw ParserError(hint: "\(string) is not a number")
        }
        return (int, string.count)
    }
}
