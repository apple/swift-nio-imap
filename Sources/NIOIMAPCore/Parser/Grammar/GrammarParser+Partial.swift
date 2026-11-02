//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
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
    /// ```
    /// partial-range       = partial-range-first / partial-range-last
    /// partial-range-first = nz-number ":" nz-number
    ///     ;; Request to search from oldest (lowest UIDs) to
    ///     ;; more recent messages.
    ///     ;; A range 500:400 is the same as 400:500.
    ///     ;; This is similar to <seq-range> from [RFC3501],
    ///     ;; but cannot contain "*".
    ///
    /// partial-range-last  = MINUS nz-number ":" MINUS nz-number
    ///     ;; Request to search from newest (highest UIDs) to
    ///     ;; oldest messages.
    ///     ;; A range -500:-400 is the same as -400:-500.
    /// ```
    func parsePartialRange(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> PartialRange {
        func parseFirst(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> PartialRange {
            let a: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let b: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            let range = (a <= b) ? SequenceRange(a...b) : SequenceRange(b...a)
            return .first(range)
        }

        func parseLast(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> PartialRange {
            try buffer.matchFixed("-")
            let a: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":-")
            let b: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            let range = (a <= b) ? SequenceRange(a...b) : SequenceRange(b...a)
            return .last(range)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseFirst(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseLast(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    /// ```
    /// ret-data-partial    = "PARTIAL"
    ///                       SP "(" partial-range SP partial-results ")"
    ///     ;; <partial-range> is the requested range.
    ///
    /// partial-results     = sequence-set / "NIL"
    ///     ;; <sequence-set> from [RFC3501].
    ///     ;; NIL indicates no results correspond to the requested range.
    /// ```
    func parseSearchReturnData_partial(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SearchReturnData {
        func parseSearchReturnData_partial_nil(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageIdentifierSet<UnknownMessageIdentifier> {
            try buffer.matchFixed("NIL")
            return MessageIdentifierSet()
        }
        func parseSearchReturnData_partial_set(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> MessageIdentifierSet<UnknownMessageIdentifier> {
            let set: LastCommandSet<UnknownMessageIdentifier>
            set = try parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker)
            guard case .set(let result) = set else {
                throw .mismatch("PARTIAL set invalid")
            }
            return result.set
        }

        try buffer.matchFixed("PARTIAL")
        try buffer.parseSpaces()
        try buffer.matchFixed("(")
        let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
        try buffer.parseSpaces()
        let set = try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseSearchReturnData_partial_nil(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseSearchReturnData_partial_set(buffer: &b, tracker: t) },
            tracker: tracker
        )
        try buffer.matchFixed(")")

        return .partial(range, set)
    }
}
