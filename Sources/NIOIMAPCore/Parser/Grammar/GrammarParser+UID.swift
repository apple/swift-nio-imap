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
    static func parseLastCommandSet<T: _IMAPEncodable>(buffer: inout ParseBuffer, tracker: StackTracker, setParser: SubParser<T>) throws -> LastCommandSet<T> {
        func parseLastCommandSet_lastCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            try ParserLibrary.fixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        func parseLastCommandSet_set(buffer: inout ParseBuffer, tracker: StackTracker) throws -> LastCommandSet<T> {
            .set(try setParser(&buffer, tracker))
        }

        return try withoutActuallyEscaping(parseLastCommandSet_set) { (parseLastCommandSet_set) in
            try ParserLibrary.oneOf([
                parseLastCommandSet_lastCommand,
                parseLastCommandSet_set,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseUid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        func parseUid_copy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("COPY ", buffer: &buffer, tracker: tracker)
                let set = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
                try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidCopy(set, mailbox)
            }
        }

        func parseUid_move(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("MOVE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidMove(set, mailbox)
            }
        }

        func parseUid_fetch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("FETCH ", buffer: &buffer, tracker: tracker)
                let set = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
                let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
                return .uidFetch(set, att, modifiers)
            }
        }

        func parseUid_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker, { buffer, tracker in
                try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
                guard case .search(let key, let charset, let returnOptions) = try self.parseSearch(buffer: &buffer, tracker: tracker) else {
                    fatalError("This should never happen")
                }
                return .uidSearch(key: key, charset: charset, returnOptions: returnOptions)
            })
        }

        func parseUid_store(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("STORE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
                let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
                return .uidStore(set, modifiers, flags)
            }
        }

        func parseUid_expunge(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.fixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            return .uidExpunge(set)
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseUid_copy,
                parseUid_move,
                parseUid_fetch,
                parseUid_search,
                parseUid_store,
                parseUid_expunge,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUIDRange(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDRange {
        func parse_wildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.fixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_UIDOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.oneOf([
                parse_wildcard,
                GrammarParser.parseUID,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndUIDOrWildcard(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UID {
            try ParserLibrary.fixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UIDRange in
            let id1 = try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: parse_colonAndUIDOrWildcard)
            if let id2 = id2 {
                return UIDRange(id1 ... id2)
            } else {
                return UIDRange(id1)
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
    static func parseUIDSet(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDSet {
        func parseUIDSet_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDRange {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return UIDRange(num)
        }

        func parseUIDSet_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDRange {
            try ParserLibrary.oneOf([
                self.parseUIDRange,
                parseUIDSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDSet_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try ParserLibrary.fixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDSet_element(buffer: &buffer, tracker: tracker)
            }
            let s = UIDSet(output)
            guard !s.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return s
        }
    }

    static func parseUIDSetNonEmpty(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDSetNonEmpty {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            guard let set = UIDSetNonEmpty(set: try self.parseUIDSet(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Need at least one UID")
            }
            return set
        }
    }

    static func parseUIDRangeArray(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [UIDRange] {
        func parseUIDArray_number(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDRange {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return UIDRange(num)
        }

        func parseUIDArray_element(buffer: inout ParseBuffer, tracker: StackTracker) throws -> UIDRange {
            try ParserLibrary.oneOf([
                self.parseUIDRange,
                parseUIDArray_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDArray_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try ParserLibrary.fixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDArray_element(buffer: &buffer, tracker: tracker)
            }

            guard !output.isEmpty else {
                throw ParserError(hint: "UID set is empty.")
            }
            return output
        }
    }
}
