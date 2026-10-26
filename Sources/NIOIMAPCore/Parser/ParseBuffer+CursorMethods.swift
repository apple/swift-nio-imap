//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

// Temporary: `ParseInput`'s method spellings over `ParserLibrary`, so the grammar can be rewritten onto
// them before the cursor itself is swapped. Removed in "Parse from ParseInput instead of ByteBuffer".
//
// Leaf primitives take no tracker on `ParseInput`; here they pass a fresh one, which only bounds their
// own single frame.
extension ParseBuffer {
    mutating func composite<T>(tracker: StackTracker, _ body: LegacySubParser<T>) throws -> T {
        try PL.composite(buffer: &self, tracker: tracker, body)
    }

    mutating func parseOptional<T>(tracker: StackTracker, parser: LegacySubParser<T>) throws -> T? {
        try PL.parseOptional(buffer: &self, tracker: tracker, parser: parser)
    }

    mutating func parseOneOf<T>(
        _ subParsers: [LegacySubParser<T>],
        tracker: StackTracker,
        file: StaticString = (#fileID),
        line: Int = #line
    ) throws -> T {
        try PL.parseOneOf(subParsers, buffer: &self, tracker: tracker, file: file, line: line)
    }

    mutating func parseOneOf<T>(
        _ parser1: LegacySubParser<T>,
        _ parser2: LegacySubParser<T>,
        tracker: StackTracker,
        file: StaticString = (#fileID),
        line: Int = #line
    ) throws -> T {
        try PL.parseOneOf(parser1, parser2, buffer: &self, tracker: tracker, file: file, line: line)
    }

    mutating func parseOneOf<T>(
        _ parser1: LegacySubParser<T>,
        _ parser2: LegacySubParser<T>,
        _ parser3: LegacySubParser<T>,
        tracker: StackTracker,
        file: StaticString = (#fileID),
        line: Int = #line
    ) throws -> T {
        try PL.parseOneOf(parser1, parser2, parser3, buffer: &self, tracker: tracker, file: file, line: line)
    }

    mutating func parseOneOrMore<T>(tracker: StackTracker, parser: LegacySubParser<T>) throws -> [T] {
        try PL.parseOneOrMore(buffer: &self, tracker: tracker, parser: parser)
    }

    mutating func parseOneOrMore<T>(into parsed: inout [T], tracker: StackTracker, parser: LegacySubParser<T>) throws {
        try PL.parseOneOrMore(buffer: &self, into: &parsed, tracker: tracker, parser: parser)
    }

    mutating func parseZeroOrMore<T>(tracker: StackTracker, parser: LegacySubParser<T>) throws -> [T] {
        try PL.parseZeroOrMore(buffer: &self, tracker: tracker, parser: parser)
    }

    mutating func parseZeroOrMore<T>(into parsed: inout [T], tracker: StackTracker, parser: LegacySubParser<T>) throws {
        try PL.parseZeroOrMore(buffer: &self, into: &parsed, tracker: tracker, parser: parser)
    }

    mutating func parseZeroOrMore<K, V>(
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: LegacySubParser<(K, V)>
    ) throws {
        try PL.parseZeroOrMore(buffer: &self, into: &orderedDictionary, tracker: tracker, parser: parser)
    }

    mutating func parseZeroOrMore<K, V>(
        into orderedDictionary: inout OrderedDictionary<K, V>,
        tracker: StackTracker,
        parser: LegacySubParser<KeyValue<K, V>>
    ) throws {
        try PL.parseZeroOrMore(buffer: &self, into: &orderedDictionary, tracker: tracker, parser: parser)
    }

    mutating func parseUnsignedInteger(
        tracker: StackTracker,
        leadingZeros: ParseInput.LeadingZeros = .rejected
    ) throws -> (number: Int, bytesConsumed: Int) {
        try PL.parseUnsignedInteger(buffer: &self, tracker: tracker, allowLeadingZeros: leadingZeros == .allowed)
    }

    mutating func parseUnsignedInt64(
        tracker: StackTracker,
        leadingZeros: ParseInput.LeadingZeros = .rejected
    ) throws -> (number: UInt64, bytesConsumed: Int) {
        try PL.parseUnsignedInt64(buffer: &self, tracker: tracker, allowLeadingZeros: leadingZeros == .allowed)
    }

    mutating func parseZeroOrMoreCharacters(where predicate: (UInt8) -> Bool) throws -> [UInt8] {
        Array(
            try PL.parseZeroOrMoreCharacters(buffer: &self, tracker: .makeNewDefault, where: predicate)
                .readableBytesView
        )
    }

    mutating func parseOneOrMoreCharacters(where predicate: (UInt8) -> Bool) throws -> [UInt8] {
        Array(
            try PL.parseOneOrMoreCharacters(buffer: &self, tracker: .makeNewDefault, where: predicate).readableBytesView
        )
    }

    mutating func parseSpaces() throws {
        try PL.parseSpaces(buffer: &self, tracker: .makeNewDefault)
    }

    mutating func matchFixed(
        _ needle: String,
        caseSensitivity: ParseInput.CaseSensitivity = .caseInsensitive,
        leadingSpaces: ParseInput.LeadingSpaces = .rejected
    ) throws {
        try PL.parseFixedString(
            needle,
            caseSensitive: caseSensitivity == .caseSensitive,
            allowLeadingSpaces: leadingSpaces == .allowed,
            buffer: &self,
            tracker: .makeNewDefault
        )
    }

    mutating func matchByte(_ needle: Character) throws {
        try PL.parseFixedByte(needle, buffer: &self, tracker: .makeNewDefault)
    }

    @discardableResult
    mutating func matchNewline() throws -> Newline {
        try PL.parseNewline(buffer: &self, tracker: .makeNewDefault)
    }

    mutating func readByte() throws -> UInt8 {
        try PL.parseByte(buffer: &self, tracker: .makeNewDefault)
    }

    mutating func extractBytes(length: Int) throws -> [UInt8] {
        Array(try PL.parseBytes(buffer: &self, tracker: .makeNewDefault, length: length).readableBytesView)
    }

    mutating func extractBuffer(upTo maxLength: Int) throws -> ByteBuffer {
        try PL.parseBytes(buffer: &self, tracker: .makeNewDefault, upTo: maxLength)
    }
}
