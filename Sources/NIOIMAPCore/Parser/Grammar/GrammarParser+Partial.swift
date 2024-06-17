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
    func parsePartialRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PartialRange {
        func parseFirst(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PartialRange {
            let a: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let b: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            let range = (a <= b) ? SequenceRange(a ... b) : SequenceRange(b ... a)
            return .first(range)
        }

        func parseLast(buffer: inout ParseBuffer, tracker: StackTracker) throws -> PartialRange {
            try PL.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let a: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(":-", buffer: &buffer, tracker: tracker)
            let b: SequenceNumber = try parseMessageIdentifier(buffer: &buffer, tracker: tracker)
            let range = (a <= b) ? SequenceRange(a ... b) : SequenceRange(b ... a)
            return .last(range)
        }

        return try PL.parseOneOf(
            parseFirst,
            parseLast,
            buffer: &buffer,
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
    func parseSearchReturnData_partial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_partial_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierSet<UnknownMessageIdentifier> {
            try PL.parseFixedString("NIL", buffer: &buffer, tracker: tracker)
            return MessageIdentifierSet()
        }
        func parseSearchReturnData_partial_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierSet<UnknownMessageIdentifier> {
            let set: LastCommandSet<UnknownMessageIdentifier>
            set = try parseMessageIdentifierSet(buffer: &buffer, tracker: tracker)
            guard case .set(let result) = set else {
                throw ParserError(hint: "PARTIAL set invalid")
            }
            return result.set
        }

        try PL.parseFixedString("PARTIAL", buffer: &buffer, tracker: tracker)
        try PL.parseSpaces(buffer: &buffer, tracker: tracker)
        try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
        try PL.parseSpaces(buffer: &buffer, tracker: tracker)
        let set = try PL.parseOneOf(
            parseSearchReturnData_partial_nil,
            parseSearchReturnData_partial_set,
            buffer: &buffer,
            tracker: tracker
        )
        try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)

        return .partial(range, set)
    }
}
