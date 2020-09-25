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

public struct TooDeep: Error {}

struct StackTracker {
    private var stackDepth = 0
    private let maximumStackDepth: Int

    static var makeNewDefaultLimitStackTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 100)
    }

    init(maximumParserStackDepth: Int) {
        self.maximumStackDepth = maximumParserStackDepth
    }

    fileprivate mutating func newStackFrame() throws {
        self.stackDepth += 1
        guard self.stackDepth < self.maximumStackDepth else {
            throw TooDeep()
        }
    }
}

extension ParserLibrary {
    static func parseZeroOrMoreCharacters(buffer: inout ByteBuffer, tracker: StackTracker, where: ((UInt8) -> Bool)) throws -> String {
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
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
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
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
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
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
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
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

    static func parseComposite<T>(buffer: inout ByteBuffer, tracker: StackTracker, _ body: SubParser<T>) throws -> T {
        var tracker = tracker
        try tracker.newStackFrame()

        let save = buffer
        do {
            return try body(&buffer, tracker)
        } catch {
            buffer = save
            throw error
        }
    }

    static func parseOneOrMore<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseOneOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseOneOrMore<T>(buffer: inout ByteBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            parsed.append(try parser(&buffer, tracker))
            while let next = try GrammarParser.optional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ByteBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
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

    static func parseNewline(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        switch buffer.getInteger(at: buffer.readerIndex, as: UInt16.self) {
        case .some(UInt16(0x0D0A /* CRLF */ )):
            // fast path: we find CRLF
            buffer.moveReaderIndex(forwardBy: 2)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\n"):
            // other fast path: we find LF + some other byte
            buffer.moveReaderIndex(forwardBy: 1)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: " "):
            // found a space that we’ll skip. Some servers insert an extra space at the end.
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
                buffer.moveReaderIndex(forwardBy: 1)
                try parseNewline(buffer: &buffer, tracker: tracker)
            }
        case .none:
            guard let first = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch first {
            case UInt8(ascii: "\n"):
                buffer.moveReaderIndex(forwardBy: 1)
                return
            case UInt8(ascii: "\r"):
                throw _IncompleteMessage()
            default:
                // found only one byte which is neither CR nor LF.
                throw ParserError()
            }
        default:
            // found two bytes but they're neither CRLF, nor start with a NL.
            throw ParserError()
        }
    }
}
