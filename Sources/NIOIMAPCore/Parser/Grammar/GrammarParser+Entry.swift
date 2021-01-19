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
    static func parseEntryValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryValue {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EntryValue in
            let name = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseMetadataValue(buffer: &buffer, tracker: tracker)
            return .init(name: name, value: value)
        }
    }

    static func parseEntryValues(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [EntryValue] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [EntryValue] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseEntryValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseEntries(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        func parseEntries_singleUnbracketed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            [try self.parseAString(buffer: &buffer, tracker: tracker)]
        }

        func parseEntries_bracketed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseEntries_singleUnbracketed,
            parseEntries_bracketed,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseEntryList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return array
        }
    }

    static func parseEntryFlagName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryFlagName {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> EntryFlagName in
            try fixedString("\"/flags/", buffer: &buffer, tracker: tracker)
            let flag = try self.parseAttributeFlag(buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return .init(flag: flag)
        }
    }

    // entry-type-req = entry-type-resp / all
    static func parseEntryKindRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryKindRequest_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindRequest_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try oneOf([
            parseEntryKindRequest_all,
            parseEntryKindRequest_private,
            parseEntryKindRequest_shared,
        ], buffer: &buffer, tracker: tracker)
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryKindResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try oneOf([
            parseEntryKindResponse_private,
            parseEntryKindResponse_shared,
        ], buffer: &buffer, tracker: tracker)
    }
}
