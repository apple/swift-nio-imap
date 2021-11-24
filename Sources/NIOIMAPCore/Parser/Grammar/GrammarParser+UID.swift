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
    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUIDRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<UID> {
        func parse_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try PL.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_UIDOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try PL.parseOneOf(
                parse_wildcard,
                self.parseUID,
                buffer: &buffer,
                tracker: tracker
            )
        }

        func parse_colonAndUIDOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try PL.parseFixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageIdentifierRange<UID> in
            let id1 = try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: parse_colonAndUIDOrWildcard)
            if let id2 = id2 {
                guard id1 <= id2 else {
                    throw ParserError(hint: "Invalid range \(id1):\(id2)")
                }
                return MessageIdentifierRange<UID>(id1 ... id2)
            } else {
                return MessageIdentifierRange<UID>(id1)
            }
        }
    }

    // uniqueid        = nz-number
    static func parseUID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
        guard let uid = UID(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "UID out of range.")
        }
        return uid
    }

    // uniqueid        = nz-number
    static func parseUIDValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDValidity {
        guard let validity = UIDValidity(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Invalid UID validity.")
        }
        return validity
    }

    // uid-set
    static func parseUIDSet(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierSet<UID> {
        func parseUIDSet_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<UID> {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return MessageIdentifierRange<UID>(num)
        }

        func parseUIDSet_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<UID> {
            try PL.parseOneOf(
                self.parseUIDRange,
                parseUIDSet_number,
                buffer: &buffer,
                tracker: tracker
            )
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDSet_element(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try PL.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDSet_element(buffer: &buffer, tracker: tracker)
            }
            let s = MessageIdentifierSet(output)
            guard !s.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return s
        }
    }

    static func parseUIDSetNonEmpty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierSetNonEmpty<UID> {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            guard let set = MessageIdentifierSetNonEmpty(set: try self.parseUIDSet(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Need at least one UID")
            }
            return set
        }
    }

    static func parseUIDRangeArray(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MessageIdentifierRange<UID>] {
        func parseUIDArray_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<UID> {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return MessageIdentifierRange<UID>(num)
        }

        func parseUIDArray_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageIdentifierRange<UID> {
            try PL.parseOneOf(
                self.parseUIDRange,
                parseUIDArray_number,
                buffer: &buffer,
                tracker: tracker
            )
        }

        return try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDArray_element(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try PL.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDArray_element(buffer: &buffer, tracker: tracker)
            }

            guard !output.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return output
        }
    }
}
