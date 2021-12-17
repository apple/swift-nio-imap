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
import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    func parseMetadataEntryName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MetadataEntryName {
        let buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return MetadataEntryName(buffer)
    }

    func parseEntryValue(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<MetadataEntryName, MetadataValue> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<MetadataEntryName, MetadataValue> in
            let name = try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseMetadataValue(buffer: &buffer, tracker: tracker)
            return .init(key: name, value: value)
        }
    }

    func parseEntryValues(buffer: inout ParseBuffer, tracker: StackTracker) throws -> OrderedDictionary<MetadataEntryName, MetadataValue> {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OrderedDictionary<MetadataEntryName, MetadataValue> in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var kvs = OrderedDictionary<MetadataEntryName, MetadataValue>()
            let ev = try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            kvs[ev.key] = ev.value
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker, parser: { buffer, tracker -> KeyValue<MetadataEntryName, MetadataValue> in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            })
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return kvs
        }
    }

    func parseEntries(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataEntryName] {
        func parseEntries_singleUnbracketed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataEntryName] {
            [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
        }

        func parseEntries_bracketed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataEntryName] {
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
            })
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try PL.parseOneOf(
            parseEntries_singleUnbracketed,
            parseEntries_bracketed,
            buffer: &buffer,
            tracker: tracker
        )
    }

    func parseEntryList(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [MetadataEntryName] {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var array = [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
            try PL.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
            })
            return array
        }
    }

    func parseEntryFlagName(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryFlagName {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> EntryFlagName in
            try PL.parseFixedString("\"/flags/", buffer: &buffer, tracker: tracker)
            let flag = try self.parseAttributeFlag(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return .init(flag: flag)
        }
    }

    // entry-type-req = entry-type-resp / all
    func parseEntryKindRequest(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try PL.parseFixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryKindRequest_private(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try PL.parseFixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindRequest_shared(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try PL.parseFixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try PL.parseOneOf(
            parseEntryKindRequest_all,
            parseEntryKindRequest_private,
            parseEntryKindRequest_shared,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // entry-type-resp = "priv" / "shared"
    func parseEntryKindResponse(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try PL.parseFixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try PL.parseFixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try PL.parseOneOf(
            parseEntryKindResponse_private,
            parseEntryKindResponse_shared,
            buffer: &buffer,
            tracker: tracker
        )
    }
}
