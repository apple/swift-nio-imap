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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // Sequence Range
    static func parseSequenceRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceRange {
        func parse_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.fixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_SequenceOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.oneOf([
                parse_wildcard,
                GrammarParser.parseSequenceNumber,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndSequenceOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.fixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SequenceRange in
            let id1 = try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: parse_colonAndSequenceOrWildcard)
            
            if let id2 = id2 {
                guard id1 <= id2 else {
                    throw ParserError(hint: "Invalid range, \(id1):\(id2)")
                }
                return SequenceRange(id1 ... id2)
            } else if id1 == .max {
                return .all
            } else {
                return SequenceRange(id1)
            }
        }
    }

    static func parseSequenceMatchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceMatchData {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.fixedString("(", buffer: &buffer, tracker: tracker)
            let knownSequenceSet = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let knownUidSet = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
            return SequenceMatchData(knownSequenceSet: knownSequenceSet, knownUidSet: knownUidSet)
        }
    }

    // SequenceNumber
    // Note: the formal syntax is bogus here.
    // "*" is a sequence range, but not a sequence number.
    static func parseSequenceNumber(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceNumber {
        guard let seq = SequenceNumber(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Sequence number out of range.")
        }
        return seq
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    // And from RFC 5182
    // sequence-set       =/ seq-last-command
    // seq-last-command   = "$"
    static func parseSequenceSet(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<SequenceRangeSet> {
        func parseSequenceSet_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceRange {
            let num = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return SequenceRange(num)
        }

        func parseSequenceSet_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceRange {
            try ParserLibrary.oneOf([
                self.parseSequenceRange,
                parseSequenceSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseSequenceSet_base(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<SequenceRangeSet> {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                var output = [try parseSequenceSet_element(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try ParserLibrary.fixedString(",", buffer: &buffer, tracker: tracker)
                    return try parseSequenceSet_element(buffer: &buffer, tracker: tracker)
                }
                guard let s = SequenceRangeSet(output) else {
                    throw ParserError(hint: "Sequence set is empty.")
                }
                return .set(s)
            }
        }

        func parseSequenceSet_lastCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<SequenceRangeSet> {
            try ParserLibrary.fixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        return try ParserLibrary.oneOf([
            parseSequenceSet_base,
            parseSequenceSet_lastCommand,
        ], buffer: &buffer, tracker: tracker)
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    static func parseModificationSequenceValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ModificationSequenceValue {
        let number = UInt64(try self.parseNumber(buffer: &buffer, tracker: tracker))
        return ModificationSequenceValue(number)
    }
}
