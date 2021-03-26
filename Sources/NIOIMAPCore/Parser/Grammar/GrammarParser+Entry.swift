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
    static func parseEntryValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<ByteBuffer, MetadataValue> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<ByteBuffer, MetadataValue> in
            let name = try self.parseAString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseMetadataValue(buffer: &buffer, tracker: tracker)
            return .init(key: name, value: value)
        }
    }

    static func parseEntryValues(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValues<ByteBuffer, MetadataValue> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValues<ByteBuffer, MetadataValue> in
            try PL.fixedString("(", buffer: &buffer, tracker: tracker)
            var kvs = KeyValues<ByteBuffer, MetadataValue>()
            kvs.append(try self.parseEntryValue(buffer: &buffer, tracker: tracker))
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker, parser: { buffer, tracker -> KeyValue<ByteBuffer, MetadataValue> in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            })
            try PL.fixedString(")", buffer: &buffer, tracker: tracker)
            return kvs
        }
    }

    static func parseEntries(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        func parseEntries_singleUnbracketed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            [try self.parseAString(buffer: &buffer, tracker: tracker)]
        }

        func parseEntries_bracketed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            try PL.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            try PL.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try PL.oneOf(
            parseEntries_singleUnbracketed,
            parseEntries_bracketed,
            buffer: &buffer,
            tracker: tracker
        )
    }

    static func parseEntryList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return array
        }
    }

    static func parseEntryFlagName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryFlagName {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> EntryFlagName in
            try PL.fixedString("\"/flags/", buffer: &buffer, tracker: tracker)
            let flag = try self.parseAttributeFlag(buffer: &buffer, tracker: tracker)
            try PL.fixedString("\"", buffer: &buffer, tracker: tracker)
            return .init(flag: flag)
        }
    }

    // entry-type-req = entry-type-resp / all
    static func parseEntryKindRequest(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try self.fixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryKindRequest_private(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try self.fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindRequest_shared(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try self.fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try self.oneOf(
            parseEntryKindRequest_all,
            parseEntryKindRequest_private,
            parseEntryKindRequest_shared,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryKindResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try self.fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try self.fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try self.oneOf(
            parseEntryKindResponse_private,
            parseEntryKindResponse_shared,
            buffer: &buffer,
            tracker: tracker
        )
    }
}
