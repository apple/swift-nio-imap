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
    func parseMessageIdentifierRange<T: MessageIdentifier>(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<T> {
        func parse_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try PL.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_identifierOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try PL.parseOneOf(
                parse_wildcard,
                self.parseMessageIdentifier,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parse_colonAndIdentifierOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageIdentifierRange<T> in
            let id1: T = try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
            let id2: T? = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parse_colonAndIdentifierOrWildcard)
            if let id2 = id2 {
                guard id1 <= id2 else {
                    throw ParserError(hint: "Invalid range, \(id1):\(id2)")
                }
                return MessageIdentifierRange(id1 ... id2)
            } else {
                return MessageIdentifierRange(id1)
            }
        }
    }

    func parseSequenceMatchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceMatchData {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let knownSequenceSet = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let knownUidSet = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return SequenceMatchData(knownSequenceSet: knownSequenceSet, knownUidSet: knownUidSet)
        }
    }

    // Parses a `MessageIdentifier`
    // Note: the formal syntax for `UID` and `SequenceNumber` is bogus here.
    // "*" is a sequence range, but not a sequence number.
    func parseMessageIdentifier<T: MessageIdentifier>(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
        guard let id = T(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Sequence number out of range.")
        }
        return id
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    // And from RFC 5182
    // sequence-set       =/ seq-last-command
    // seq-last-command   = "$"
    func parseMessageIdentifierSet<T: MessageIdentifier>(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<MessageIdentifierSet<T>> {
        func parseMessageIdentifierSet_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<T> {
            MessageIdentifierRange<T>(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageIdentifierSet_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<T> {
            try PL.parseOneOf(
                self.parseMessageIdentifierRange,
                parseMessageIdentifierSet_number,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parseMessageIdentifierSet_base(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<MessageIdentifierSet<T>> {
            try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                var output: [MessageIdentifierRange<T>] = [try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)]
                try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try PL.parseFixedString(",", buffer: &buffer, tracker: tracker)
                    return try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)
                }
                guard !output.isEmpty else {
                    throw ParserError(hint: "Sequence set is empty.")
                }
                return .set(.init(output))
            }
        }

        func parseMessageIdentifierSet_lastCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<MessageIdentifierSet<T>> {
            try PL.parseFixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        return try PL.parseOneOf(
            parseMessageIdentifierSet_base,
            parseMessageIdentifierSet_lastCommand,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    func parseModificationSequenceValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ModificationSequenceValue {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let (number, _) = try ParserLibrary.parseUnsignedInt64(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
            guard let v = ModificationSequenceValue(exactly: number) else {
                throw ParserError(hint: "Mod-seq value is too large.")
            }
            return v
        }
    }
}
