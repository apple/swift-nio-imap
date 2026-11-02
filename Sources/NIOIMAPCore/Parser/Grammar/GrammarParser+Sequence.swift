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

extension GrammarParser {
    // Sequence Range
    func parseMessageIdentifierRange<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MessageIdentifierRange<T> {
        func parse_wildcard(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> T {
            try buffer.matchFixed("*")
            return .max
        }

        func parse_identifierOrWildcard(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> T {
            try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parse_wildcard(buffer: &b, tracker: t) },
                self.parseMessageIdentifier,
                tracker: tracker
            )
        }

        func parse_colonAndIdentifierOrWildcard(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> T {
            try buffer.matchFixed(":")
            return try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try buffer.composite(tracker: tracker) {
            buffer,
            tracker throws(ParseFailure) -> MessageIdentifierRange<T> in
            let id1: T = try parse_identifierOrWildcard(buffer: &buffer, tracker: tracker)
            let id2: T? = try buffer.parseOptional(
                tracker: tracker,
                parser: { b, t throws(ParseFailure) in try parse_colonAndIdentifierOrWildcard(buffer: &b, tracker: t) }
            )
            guard let id2 = id2 else {
                return MessageIdentifierRange(id1)
            }
            return (id1 <= id2) ? MessageIdentifierRange(id1...id2) : MessageIdentifierRange(id2...id1)
        }
    }

    func parseSequenceMatchData(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SequenceMatchData {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
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
    func parseMessageIdentifier<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> T {
        guard let id = T(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw .mismatch("Sequence number out of range.")
        }
        return id
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    func parseMessageIdentifierSet<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> MessageIdentifierSetNonEmpty<T> {
        func parseMessageIdentifierSet_number(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageIdentifierRange<T> {
            MessageIdentifierRange<T>(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseMessageIdentifierSet_element(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageIdentifierRange<T> {
            try buffer.parseOneOf(
                self.parseMessageIdentifierRange,
                { b, t throws(ParseFailure) in try parseMessageIdentifierSet_number(buffer: &b, tracker: t) },
                tracker: tracker
            )
        }

        var output: [MessageIdentifierRange<T>] = [
            try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)
        ]
        try buffer.parseZeroOrMore(into: &output, tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed(",")
            return try parseMessageIdentifierSet_element(buffer: &buffer, tracker: tracker)
        }
        let set = MessageIdentifierSet(output)
        guard let nonEmpty = MessageIdentifierSetNonEmpty(set: set) else {
            throw .mismatch("Sequence set is empty.")
        }
        return nonEmpty
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    // And from RFC 5182
    // sequence-set       =/ seq-last-command
    // seq-last-command   = "$"
    func parseMessageIdentifierSetOrLast<T: MessageIdentifier>(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> LastCommandSet<T> {
        func parseMessageIdentifierSet_base(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandSet<T> {
            .set(try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageIdentifierSet_lastCommand(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> LastCommandSet<T> {
            try buffer.matchFixed("$")
            return .lastCommand
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseMessageIdentifierSet_base(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseMessageIdentifierSet_lastCommand(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    func parseModificationSequenceValue(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ModificationSequenceValue {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let (number, _) = try buffer.parseUnsignedInt64(
                tracker: tracker,
                leadingZeros: .allowed
            )
            guard let v = ModificationSequenceValue(exactly: number) else {
                throw .mismatch("Mod-seq value is too large.")
            }
            return v
        }
    }
}
