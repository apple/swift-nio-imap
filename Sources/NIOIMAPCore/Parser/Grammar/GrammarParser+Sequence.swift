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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // Sequence Range
    func parseMessageIdentifierRange<T: MessageIdentifier>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> MessageIdentifierRange<T> {
        func parse_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try buffer.matchFixed("*")
            return .max
        }

        func parse_identifierOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try buffer.parseOneOf(
                { try parse_wildcard(buffer: &$0, tracker: $1) },
                self.parseMessageIdentifier,
                tracker: tracker
            )
        }

        func parse_colonAndIdentifierOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> T {
            try buffer.matchFixed(":")
            return try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker -> MessageIdentifierRange<T> in
            let id1: T = try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
            let id2: T? = try buffer.parseOptional(
                tracker: tracker,
                parser: { try parse_colonAndIdentifierOrWildcard(buffer: &$0, tracker: $1) }
            )
            guard let id2 = id2 else {
                return MessageIdentifierRange(id1)
            }
            return (id1 <= id2) ? MessageIdentifierRange(id1...id2) : MessageIdentifierRange(id2...id1)
        }
    }

    func parseSequenceMatchData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SequenceMatchData {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed("(")
            let knownSequenceSet = try self.parseLastCommandSet(
                buffer: &buffer,
                tracker: tracker,
                setParser: self.parseUIDSetNonEmpty
            )
            try buffer.parseSpaces()
            let knownUidSet = try self.parseLastCommandSet(
                buffer: &buffer,
                tracker: tracker,
                setParser: self.parseUIDSetNonEmpty
            )
            try buffer.matchFixed(")")
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
    func parseMessageIdentifierSet<T: MessageIdentifier>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> MessageIdentifierSetNonEmpty<T> {
        func parseMessageIdentifierSet_number(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageIdentifierRange<T> {
            MessageIdentifierRange<T>(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageIdentifierSet_element(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> MessageIdentifierRange<T> {
            try buffer.parseOneOf(
                self.parseMessageIdentifierRange,
                { try parseMessageIdentifierSet_number(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }

        var output: [MessageIdentifierRange<T>] = [
            try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)
        ]
        try buffer.parseZeroOrMore(into: &output, tracker: tracker) { buffer, tracker in
            try buffer.matchFixed(",")
            return try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)
        }
        let set = MessageIdentifierSet(output)
        guard let nonEmpty = MessageIdentifierSetNonEmpty(set: set) else {
            throw ParserError(hint: "Sequence set is empty.")
        }
        return nonEmpty
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    // And from RFC 5182
    // sequence-set       =/ seq-last-command
    // seq-last-command   = "$"
    func parseMessageIdentifierSetOrLast<T: MessageIdentifier>(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> LastCommandSet<T> {
        func parseMessageIdentifierSet_base(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> LastCommandSet<T> {
            .set(try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageIdentifierSet_lastCommand(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> LastCommandSet<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        return try buffer.parseOneOf(
            { try parseMessageIdentifierSet_base(buffer: &$0, tracker: $1) },
            { try parseMessageIdentifierSet_lastCommand(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    func parseModificationSequenceValue(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ModificationSequenceValue {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            let (number, _) = try buffer.parseUnsignedInt64(
                tracker: tracker,
                leadingZeros: .allowed
            )
            guard let v = ModificationSequenceValue(exactly: number) else {
                throw ParserError(hint: "Mod-seq value is too large.")
            }
            return v
        }
    }
}
