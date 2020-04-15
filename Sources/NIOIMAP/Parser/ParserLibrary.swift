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

import NIO

enum ParserLibrary {}

typealias SubParser<ByteBufferType: ByteBufferProtocol, T> = (inout ByteBufferType, StackTracker) throws -> T

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
        return StackTracker(maximumParserStackDepth: 100)
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
    static func parseZeroOrMoreCharacters<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker, where: ((ByteBufferType.ReadableBytesViewType.Element) -> Bool)) throws -> String {
        return try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                return !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            return buffer.readString(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMoreCharacters<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker, where: ((ByteBufferType.ReadableBytesViewType.Element) -> Bool)) throws -> String {
        return try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                return !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            guard firstBad != buffer.readableBytesView.startIndex else {
                throw ParserError(hint: "couldn't find one or more of the required characters")
            }
            return buffer.readString(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseZeroOrMoreCharactersByteBuffer<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker, where: ((ByteBufferType.ReadableBytesViewType.Element) -> Bool)) throws -> ByteBufferType {
        return try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                return !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            return buffer.readSlice(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMoreCharactersByteBuffer<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker, where: ((ByteBufferType.ReadableBytesViewType.Element) -> Bool)) throws -> ByteBufferType {
        return try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let maybeFirstBad = buffer.readableBytesView.firstIndex { char in
                return !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            guard firstBad != buffer.readableBytesView.startIndex else {
                throw ParserError()
            }
            return buffer.readSlice(length: buffer.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseComposite<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, tracker: StackTracker, _ body: SubParser<ByteBufferType, T>) throws -> T {
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

    static func parseOptional<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, tracker: StackTracker, parser: SubParser<ByteBufferType, T>) throws -> T? {
        do {
            return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker, parser)
        } catch is ParserError {
            return nil
        }
    }

    static func parseOneOrMore<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, tracker: StackTracker, parser: SubParser<ByteBufferType, T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseOneOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseOneOrMore<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, into parsed: inout [T], tracker: StackTracker, parser: SubParser<ByteBufferType, T>) throws {
        try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            parsed.append(try parser(&buffer, tracker))
            while let next = try self.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }
    
    static func parseZeroOrMore<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, into parsed: inout [T], tracker: StackTracker, parser: SubParser<ByteBufferType, T>) throws {
        return try Self.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try self.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<ByteBufferType: ByteBufferProtocol, T>(buffer: inout ByteBufferType, tracker: StackTracker, parser: SubParser<ByteBufferType, T>) throws -> [T] {
        var parsed: [T] = []
        try Self.parseZeroOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }
    
    static func parseOneOf<ByteBufferType: ByteBufferProtocol, T>(_ subParsers: [SubParser<ByteBufferType, T>], buffer: inout ByteBufferType, tracker: StackTracker, file: String = #file, line: Int = #line) throws -> T {
        for parser in subParsers {
            do {
                return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker, parser)
            } catch is ParserError {
                continue
            }
        }
        throw ParserError(hint: "none of the options match", file: file, line: line)
    }

    static func parseFixedString<ByteBufferType: ByteBufferProtocol>(_ needle: String, caseSensitive: Bool = false, buffer: inout ByteBufferType, tracker: StackTracker) throws {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let needleCount = needle.utf8.count
            guard let actual = buffer.readString(length: needleCount) else {
                guard needle.utf8.starts(with: buffer.readableBytesView, by: { $0 & 0xdf == $1 & 0xdf }) else {
                    throw ParserError(hint: "Tried to parse \(needle) in \(String(decoding: buffer.readableBytesView, as: Unicode.UTF8.self))")
                }
                throw NIOIMAP.ParsingError.incompleteMessage
            }

            assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
            if actual == needle {
                // great, we just match
                return
            } else if !caseSensitive {
                // we know this is all ASCII so we can do an ASCII case-insensitive compare here
                guard needleCount == actual.utf8.count &&
                    actual.utf8.elementsEqual(needle.utf8, by: { ($0 & 0xdf) == ($1 & 0xdf) }) else {
                    throw ParserError(hint: "case insensitively looking for \(needle) found \(actual)")
                }
                return
            } else {
                throw ParserError(hint: "case sensitively looking for \(needle) found \(actual)")
            }
        }
    }
    
    static func parseSpace<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker) throws {
        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            guard let actual = buffer.readString(length: 1) else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            guard actual == " " else {
                throw ParserError(hint: "Expected space, found \(actual)")
            }
        }
    }
    
    static func parseUnsignedInteger<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker) throws -> (number: Int, bytesConsumed: Int) {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
            return char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")
        }
        guard let int = Int(string) else {
            throw ParserError(hint: "\(string) is not a number")
        }
        return (int, string.count)
    }

    static func parseNewline<ByteBufferType: ByteBufferProtocol>(buffer: inout ByteBufferType, tracker: StackTracker) throws {
        switch buffer.getInteger(at: buffer.readerIndex, endianness: .bigEndian(), as: UInt16.self) {
        case .some(UInt16(0x0d0a /* CRLF */)):
            // fast path: we find CRLF
            buffer.moveReaderIndex(forwardBy: 2)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\n"):
            // other fast path: we find LF + some other byte
            buffer.moveReaderIndex(forwardBy: 1)
            return
        case .none:
            guard let first = buffer.getInteger(at: buffer.readerIndex, endianness: .bigEndian(), as: UInt8.self) else {
                throw NIOIMAP.ParsingError.incompleteMessage
            }
            switch first {
            case UInt8(ascii: "\n"):
                buffer.moveReaderIndex(forwardBy: 1)
                return
            case UInt8(ascii: "\r"):
                throw NIOIMAP.ParsingError.incompleteMessage
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
