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

    init(hint: String = "Unknown", file: String = #file, line: Int = #line) {
        self.hint = hint
        self.file = file
        self.line = line
    }
}

public struct TooDeep: Error {}

struct StackTracker {
    private var stackDepth = 0
    private let maximumStackDepth: Int

    static var new: StackTracker {
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
                throw ParsingError.incompleteMessage
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
                throw ParsingError.incompleteMessage
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
                throw ParsingError.incompleteMessage
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
                throw ParsingError.incompleteMessage
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

    static func parseOptional<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> T? {
        do {
            return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker, parser)
        } catch is ParserError {
            return nil
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
            while let next = try self.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ByteBuffer, into parsed: inout [T], tracker: StackTracker, parser: SubParser<T>) throws {
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try self.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseZeroOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseOneOf<T>(_ subParsers: [SubParser<T>], buffer: inout ByteBuffer, tracker: StackTracker, file: String = #file, line: Int = #line) throws -> T {
        for parser in subParsers {
            do {
                return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker, parser)
            } catch is ParserError {
                continue
            }
        }
        throw ParserError(hint: "none of the options match", file: file, line: line)
    }

    static func parseFixedString(_ needle: String, caseSensitive: Bool = false, buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let needleCount = needle.utf8.count
            guard let actual = buffer.readString(length: needleCount) else {
                guard needle.utf8.starts(with: buffer.readableBytesView, by: { $0 & 0xDF == $1 & 0xDF }) else {
                    throw ParserError(hint: "Tried to parse \(needle) in \(String(decoding: buffer.readableBytesView, as: Unicode.UTF8.self))")
                }
                throw ParsingError.incompleteMessage
            }

            assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
            if actual == needle {
                // great, we just match
                return
            } else if !caseSensitive {
                // we know this is all ASCII so we can do an ASCII case-insensitive compare here
                guard needleCount == actual.utf8.count,
                    actual.utf8.elementsEqual(needle.utf8, by: { ($0 & 0xDF) == ($1 & 0xDF) }) else {
                    throw ParserError(hint: "case insensitively looking for \(needle) found \(actual)")
                }
                return
            } else {
                throw ParserError(hint: "case sensitively looking for \(needle) found \(actual)")
            }
        }
    }

    static func parseSpace(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, _ in
            guard let actual = buffer.readString(length: 1) else {
                throw ParsingError.incompleteMessage
            }
            guard actual == " " else {
                throw ParserError(hint: "Expected space, found \(actual)")
            }
        }
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
        case .none:
            guard let first = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
                throw ParsingError.incompleteMessage
            }
            switch first {
            case UInt8(ascii: "\n"):
                buffer.moveReaderIndex(forwardBy: 1)
                return
            case UInt8(ascii: "\r"):
                throw ParsingError.incompleteMessage
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
