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
    // uniqueid        = nz-number
    func parseUIDValidity(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDValidity {
        guard let validity = UIDValidity(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Invalid UID validity.")
        }
        return validity
    }

    // uid-set
    func parseUIDSet(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDSet {
        func parseUIDSet_number(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDRange {
            UIDRange(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseUIDSet_element(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDRange {
            try buffer.parseOneOf(
                self.parseMessageIdentifierRange,
                { try parseUIDSet_number(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            var output = [try parseUIDSet_element(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) { buffer, tracker in
                try buffer.matchFixed(",")
                return try parseUIDSet_element(buffer: &buffer, tracker: tracker)
            }
            let s = MessageIdentifierSet(output)
            guard !s.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return s
        }
    }

    func parseUIDSetNonEmpty(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> MessageIdentifierSetNonEmpty<UID> {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            guard let set = MessageIdentifierSetNonEmpty(set: try self.parseUIDSet(buffer: &buffer, tracker: tracker))
            else {
                throw ParserError(hint: "Need at least one UID")
            }
            return set
        }
    }

    func parseUIDRangeArray(buffer: inout ParseInput, tracker: StackTracker) throws -> [UIDRange] {
        func parseUIDArray_number(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDRange {
            UIDRange(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseUIDArray_element(buffer: inout ParseInput, tracker: StackTracker) throws -> UIDRange {
            try buffer.parseOneOf(
                self.parseMessageIdentifierRange,
                { try parseUIDArray_number(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker in
            var output = [try parseUIDArray_element(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &output, tracker: tracker) { buffer, tracker in
                try buffer.matchFixed(",")
                return try parseUIDArray_element(buffer: &buffer, tracker: tracker)
            }

            guard !output.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return output
        }
    }
}
