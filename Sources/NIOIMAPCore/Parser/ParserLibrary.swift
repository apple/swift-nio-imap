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
import struct OrderedCollections.OrderedDictionary

enum ParserLibrary {}

struct IncompleteMessage: Error {
    fileprivate init() {}
}

typealias SubParser<T> = (inout ParseBuffer, StackTracker) throws -> T

internal struct ParseBuffer: Hashable {
    fileprivate var bytes: ByteBuffer
    /// Last newline parsed by `parseNewline()`
    fileprivate(set) internal var lastParsedNewline: Newline?

    internal init(_ bytes: ByteBuffer) {
        self.bytes = bytes
        self.lastParsedNewline = nil
    }

    internal var readableBytes: Int {
        self.bytes.readableBytes
    }
}

extension ParseBuffer {
    /// Line ending kind
    enum Newline: Sendable, Hashable {
        case crlf
        case cr
        case lf
    }

    enum SkipLFResult: Hashable, Sendable {
        case didSkip
        case none
    }

    /// Skip an `LF` if it's the first byte in the buffer.
    mutating func skipLF() -> SkipLFResult {
        guard
            let first = bytes.getInteger(
                at: bytes.readerIndex,
                as: UInt8.self
            ),
            first == UInt8(ascii: "\n")
        else { return .none }
        bytes.moveReaderIndex(forwardBy: 1)
        return .didSkip
    }
}

/// Parsing a tagged command failed. Includes the tag of the invalid command, and the parsing error.
///
/// When the server receives a command from a client, it includes a tag for correlation.
/// If the command line cannot be parsed, this error includes both the tag (so the server
/// can send back a properly-tagged error response) and details about what went wrong.
///
/// - SeeAlso: ``ParserError``, [RFC 3501 Section 6.1](https://datatracker.ietf.org/doc/html/rfc3501#section-6.1)
public struct BadCommand: Error {
    /// The tag of the bad command.
    ///
    /// This allows the server to send a properly-tagged error response to the client,
    /// maintaining IMAP's request/response correlation even when the command is malformed.
    public var commandTag: String

    /// Why parsing failed.
    ///
    /// Contains a human-readable hint about the parsing error and source location information.
    public var parserError: ParserError
}

/// An error occurred when parsing an IMAP command or response.
///
/// `ParserError` is thrown when the IMAP protocol parser encounters bytes that cannot be
/// interpreted according to the IMAP grammar (RFC 3501 or extensions). Common causes include:
/// - Invalid UTF-8 sequences in string fields
/// - Malformed protocol syntax (e.g., unexpected characters or missing required elements)
/// - Non-conforming protocol elements
///
/// The ``hint`` field provides a developer-friendly description of what went wrong.
/// The internal file and line information is useful for debugging parser issues.
///
/// - SeeAlso: [RFC 3501 Section 4](https://datatracker.ietf.org/doc/html/rfc3501#section-4) (grammar)
public struct ParserError: Error {
    static func invalidUTF8(file: String = (#fileID), line: Int = #line) -> Self {
        ParserError(hint: "Invalid UTF8", file: file, line: line)
    }

    /// If possible, a description of the error and why it occurred.
    ///
    /// This hint describes the parsing failure in human-readable terms, such as
    /// "Invalid UTF8", "Missing CRLF", "Unexpected character", etc. It's intended
    /// for logging and debugging purposes.
    public var hint: String
    var file: String
    var line: Int

    init(hint: String = "Unknown", file: String = (#fileID), line: Int = #line) {
        self.hint = hint
        self.file = file
        self.line = line
    }
}

/// Signals that a protocol message was too complex and required excessive recursive parsing.
///
/// IMAP protocol elements can nest (e.g., nested parenthesized lists in BODYSTRUCTURE),
/// and parsing uses recursion to handle this. To prevent stack overflow attacks,
/// the parser enforces a maximum recursion depth. If this limit is exceeded, this error
/// is thrown.
///
/// This is a safety limit to prevent malicious or extremely unusual protocol messages
/// from causing a stack overflow.
///
/// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3) (protocol syntax)
public struct TooMuchRecursion: Error {
    /// The maximum number of recursive calls when parsing data before throwing an error.
    ///
    /// The parser maintains a recursion depth counter and throws this error when the
    /// depth would exceed this limit. This prevents stack overflow from deeply nested
    /// protocol structures.
    ///
    /// This limit is currently fixed at compile-time and not configurable at runtime.
    public var limit: Int

    init(limit: Int) {
        self.limit = limit
    }
}

extension ParserLibrary {
    /// Throws `ParserError.invalidUTF8` if the given `ByteBuffer` doesn't
    /// contain a valid UTF8 sequence.
    static func parseBufferAsUTF8(_ buffer: ByteBuffer, file: String = (#fileID), line: Int = #line) throws -> String {
        guard let string = String(validatingUTF8Bytes: buffer.readableBytesView) else {
            throw ParserError.invalidUTF8(file: file, line: line)
        }
        return string
    }

    static func parseZeroOrMoreCharacters(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        where: ((UInt8) -> Bool)
    ) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.bytes.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw IncompleteMessage()
            }
            return buffer.bytes.readSlice(length: buffer.bytes.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMoreCharacters(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        where: ((UInt8) -> Bool)
    ) throws -> ByteBuffer {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let maybeFirstBad = buffer.bytes.readableBytesView.firstIndex { char in
                !`where`(char)
            }

            guard let firstBad = maybeFirstBad else {
                throw IncompleteMessage()
            }
            guard firstBad != buffer.bytes.readableBytesView.startIndex else {
                let badByte = buffer.bytes.readableBytesView[firstBad]
                throw ParserError(hint: "Found unexpected \(Character(.init(badByte)))")
            }
            return buffer.bytes.readSlice(length: buffer.bytes.readableBytesView.startIndex.distance(to: firstBad))!
        }
    }

    static func parseOneOrMore<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T]
    {
        var parsed: [T] = []
        try Self.parseOneOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseOneOrMore<T>(
        buffer: inout ParseBuffer,
        into parsed: inout [T],
        tracker: StackTracker,
        parser: SubParser<T>
    ) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            parsed.append(try parser(&buffer, tracker))
            while let next = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<T>(
        buffer: inout ParseBuffer,
        into parsed: inout [T],
        tracker: StackTracker,
        parser: SubParser<T>
    ) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                parsed.append(next)
            }
        }
    }

    static func parseZeroOrMore<K, V>(
        buffer: inout ParseBuffer,
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: SubParser<(K, V)>
    ) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                orderedDictionary[next.0] = next.1
            }
        }
    }

    static func parseZeroOrMore<K, V>(
        buffer: inout ParseBuffer,
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: SubParser<KeyValue<K, V>>
    ) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            while let next = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parser) {
                orderedDictionary[next.key] = next.value
            }
        }
    }

    static func parseZeroOrMore<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> [T]
    {
        var parsed: [T] = []
        try Self.parseZeroOrMore(buffer: &buffer, into: &parsed, tracker: tracker, parser: parser)
        return parsed
    }

    static func parseUnsignedInteger(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        allowLeadingZeros: Bool = false
    ) throws -> (number: Int, bytesConsumed: Int) {
        let largeInt = try self.parseUnsignedInt64(
            buffer: &buffer,
            tracker: tracker,
            allowLeadingZeros: allowLeadingZeros
        )
        guard let int = Int(exactly: largeInt.number) else {
            throw ParserError(hint: "integer too large")
        }
        return (number: int, bytesConsumed: largeInt.bytesConsumed)
    }

    static func parseUnsignedInt64(
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        allowLeadingZeros: Bool = false
    ) throws -> (number: UInt64, bytesConsumed: Int) {
        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let parsed = try PL.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char in
                char >= UInt8(ascii: "0") && char <= UInt8(ascii: "9")
            }
            let string = try ParserLibrary.parseBufferAsUTF8(parsed)
            guard let int = UInt64(string) else {
                throw ParserError(hint: "\(string) is not a number")
            }
            if !allowLeadingZeros, string.utf8.first! == UInt8(ascii: "0") {
                throw ParserError(hint: "starts with 0")
            }
            return (int, string.count)
        }
    }

    static func parseSpaces(buffer: inout ParseBuffer, tracker: StackTracker) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, _ in

            // need at least one readable byte
            guard buffer.bytes.readableBytes > 0 else { throw IncompleteMessage() }

            // if there are only spaces then just consume it all and move on
            guard let index = buffer.bytes.readableBytesView.firstIndex(where: { $0 != UInt8(ascii: " ") }) else {
                buffer.bytes.moveReaderIndex(to: buffer.bytes.writerIndex)
                return
            }

            // first character wasn't a space
            guard index > buffer.bytes.readableBytesView.startIndex else {
                throw ParserError(hint: "Expected space, found \(buffer.bytes.readableBytesView[index])")
            }

            buffer.bytes.moveReaderIndex(to: index)
        }
    }

    static func parseFixedString(
        _ needle: String,
        caseSensitive: Bool = false,
        allowLeadingSpaces: Bool = false,
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in

            if allowLeadingSpaces {
                try self.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSpaces)
            }

            let needleCount = needle.utf8.count
            guard let actual = buffer.bytes.readString(length: needleCount) else {
                guard needle.utf8.starts(with: buffer.bytes.readableBytesView, by: { $0 & 0xDF == $1 & 0xDF }) else {
                    throw ParserError(
                        hint:
                            "Tried to parse \(needle) in \(String(decoding: buffer.bytes.readableBytesView, as: Unicode.UTF8.self))"
                    )
                }
                throw IncompleteMessage()
            }

            assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
            if actual == needle {
                // great, we just match
            } else if !caseSensitive {
                // we know this is all ASCII so we can do an ASCII case-insensitive compare here
                guard needleCount == actual.utf8.count,
                    actual.utf8.elementsEqual(needle.utf8, by: { ($0 & 0xDF) == ($1 & 0xDF) })
                else {
                    throw ParserError(hint: "case insensitively looking for \(needle) found \(actual)")
                }
            } else {
                throw ParserError(hint: "case sensitively looking for \(needle) found \(actual)")
            }
        }
    }

    static func parseFixedByte(_ needle: Character, buffer: inout ParseBuffer, tracker: StackTracker) throws {
        assert(needle.isASCII)
        let needleByte = needle.asciiValue!
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let byte = try parseByte(buffer: &buffer, tracker: tracker)
            guard byte == needleByte
            else {
                throw ParserError(hint: "looking for \(needleByte) found \(byte)")
            }
        }
    }

    static func parseOneOf<T>(
        _ subParsers: [SubParser<T>],
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        file: String = (#fileID),
        line: Int = #line
    ) throws -> T {
        for parser in subParsers {
            do {
                return try PL.composite(buffer: &buffer, tracker: tracker, parser)
            } catch is ParserError {
                continue
            } catch is BadCommand {
                continue
            }
        }
        throw ParserError(hint: "none of the options match", file: file, line: line)
    }

    static func parseOneOf<T>(
        _ parser1: SubParser<T>,
        _ parser2: SubParser<T>,
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        file: String = (#fileID),
        line: Int = #line
    ) throws -> T {
        do {
            return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parser1(&buffer, tracker)
            }
        } catch is ParserError {
            // ok
            // TODO: Condense when we drop 5.2
        } catch is BadCommand {
            // ok
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try parser2(&buffer, tracker)
        }
    }

    static func parseOneOf<T>(
        _ parser1: SubParser<T>,
        _ parser2: SubParser<T>,
        _ parser3: SubParser<T>,
        buffer: inout ParseBuffer,
        tracker: StackTracker,
        file: String = (#fileID),
        line: Int = #line
    ) throws -> T {
        do {
            return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parser1(&buffer, tracker)
            }
        } catch is ParserError {
            // ok
            // TODO: Condense when we drop 5.2
        } catch is BadCommand {
            // ok
        }

        do {
            return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parser2(&buffer, tracker)
            }
        } catch is ParserError {
            // ok
            // TODO: Condense when we drop 5.2
        } catch is BadCommand {
            // ok
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try parser3(&buffer, tracker)
        }
    }

    static func parseOptional<T>(buffer: inout ParseBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> T? {
        do {
            return try PL.composite(buffer: &buffer, tracker: tracker, parser)
        } catch is ParserError {
            return nil
        }
    }

    static func composite<T>(buffer: inout ParseBuffer, tracker: StackTracker, _ body: SubParser<T>) throws -> T {
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

    @discardableResult
    static func parseNewline(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ParseBuffer.Newline {
        func _parseNewline() throws -> ParseBuffer.Newline {
            switch buffer.bytes.getInteger(at: buffer.bytes.readerIndex, as: UInt16.self) {
            case .some(UInt16(0x0D0A)):  // CRLF
                // fast path: we find CRLF
                buffer.bytes.moveReaderIndex(forwardBy: 2)
                return .crlf
            case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\n"):
                // other fast path: we find LF + some other byte
                buffer.bytes.moveReaderIndex(forwardBy: 1)
                return .lf
            case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\r"):
                // CR followed by some other byte
                buffer.bytes.moveReaderIndex(forwardBy: 1)
                return .cr
            case .some(let x) where UInt8(x >> 8) == UInt8(ascii: " "):
                // found a space that we’ll skip. Some servers insert an extra space at the end.
                return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    buffer.bytes.moveReaderIndex(forwardBy: 1)
                    return try PL.parseNewline(buffer: &buffer, tracker: tracker)
                }
            case .none:
                guard let first = buffer.bytes.getInteger(at: buffer.bytes.readerIndex, as: UInt8.self) else {
                    throw IncompleteMessage()
                }
                switch first {
                case UInt8(ascii: "\n"):
                    buffer.bytes.moveReaderIndex(forwardBy: 1)
                    return .lf
                case UInt8(ascii: "\r"):
                    buffer.bytes.moveReaderIndex(forwardBy: 1)
                    return .cr
                default:
                    // found only one byte which is neither CR nor LF.
                    throw ParserError()
                }
            default:
                // found two bytes but they’re neither CRLF, nor start with a NL.
                throw ParserError()
            }
        }
        let result = try _parseNewline()
        buffer.lastParsedNewline = result
        return result
    }

    static func parseByte(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UInt8 {
        guard let byte = buffer.bytes.readInteger(as: UInt8.self) else {
            throw IncompleteMessage()
        }
        return byte
    }

    static func parseBytes(buffer: inout ParseBuffer, tracker: StackTracker, length: Int) throws -> ByteBuffer {
        guard let bytes = buffer.bytes.readSlice(length: length) else {
            throw IncompleteMessage()
        }
        return bytes
    }

    static func parseBytes(buffer: inout ParseBuffer, tracker: StackTracker, upTo maxLength: Int) throws -> ByteBuffer {
        guard buffer.readableBytes > 0 else {
            throw IncompleteMessage()
        }

        guard buffer.bytes.readableBytes >= maxLength else {
            return buffer.bytes.readSlice(length: buffer.bytes.readableBytes)!  // safe, those bytes are readable.
        }
        return buffer.bytes.readSlice(length: maxLength)!  // safe, those bytes are readable.
    }
}
