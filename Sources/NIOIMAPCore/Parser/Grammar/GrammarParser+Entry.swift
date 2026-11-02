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
import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    func parseMetadataEntryName(buffer: inout ParseInput, tracker: StackTracker) throws -> MetadataEntryName {
        let buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return MetadataEntryName(buffer)
    }

    func parseEntryValue(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> KeyValue<MetadataEntryName, MetadataValue> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker -> KeyValue<MetadataEntryName, MetadataValue> in
            let name = try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let value = try self.parseMetadataValue(buffer: &buffer, tracker: tracker)
            return .init(key: name, value: value)
        }
    }

    func parseEntryValues(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> OrderedDictionary<MetadataEntryName, MetadataValue> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker -> OrderedDictionary<MetadataEntryName, MetadataValue> in
            try buffer.matchFixed("(")
            var kvs = OrderedDictionary<MetadataEntryName, MetadataValue>()
            let ev = try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            kvs[ev.key] = ev.value
            try buffer.parseZeroOrMore(
                into: &kvs,
                tracker: tracker,
                parser: { buffer, tracker -> KeyValue<MetadataEntryName, MetadataValue> in
                    try buffer.parseSpaces()
                    return try self.parseEntryValue(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return kvs
        }
    }

    func parseEntries(buffer: inout ParseInput, tracker: StackTracker) throws -> [MetadataEntryName] {
        func parseEntries_singleUnbracketed(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> [MetadataEntryName] {
            [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
        }

        func parseEntries_bracketed(buffer: inout ParseInput, tracker: StackTracker) throws -> [MetadataEntryName] {
            try buffer.matchFixed("(")
            var array = [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { buffer, tracker in
                    try buffer.parseSpaces()
                    return try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        }

        return try buffer.parseOneOf(
            { try parseEntries_singleUnbracketed(buffer: &$0, tracker: $1) },
            { try parseEntries_bracketed(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    func parseEntryList(buffer: inout ParseInput, tracker: StackTracker) throws -> [MetadataEntryName] {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            var array = [try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { buffer, tracker in
                    try buffer.parseSpaces()
                    return try self.parseMetadataEntryName(buffer: &buffer, tracker: tracker)
                }
            )
            return array
        }
    }

    func parseEntryFlagName(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryFlagName {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> EntryFlagName in
            try buffer.matchFixed("\"/flags/")
            let flag = try self.parseAttributeFlag(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("\"")
            return .init(flag: flag)
        }
    }

    // entry-type-req = entry-type-resp / all
    func parseEntryKindRequest(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindRequest {
            try buffer.matchFixed("all")
            return .all
        }

        func parseEntryKindRequest_private(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindRequest {
            try buffer.matchFixed("priv")
            return .private
        }

        func parseEntryKindRequest_shared(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindRequest {
            try buffer.matchFixed("shared")
            return .shared
        }

        return try buffer.parseOneOf(
            { try parseEntryKindRequest_all(buffer: &$0, tracker: $1) },
            { try parseEntryKindRequest_private(buffer: &$0, tracker: $1) },
            { try parseEntryKindRequest_shared(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // entry-type-resp = "priv" / "shared"
    func parseEntryKindResponse(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> EntryKindResponse {
            try buffer.matchFixed("priv")
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ParseInput, tracker: StackTracker) throws -> EntryKindResponse
        {
            try buffer.matchFixed("shared")
            return .shared
        }

        return try buffer.parseOneOf(
            { try parseEntryKindResponse_private(buffer: &$0, tracker: $1) },
            { try parseEntryKindResponse_shared(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }
}
