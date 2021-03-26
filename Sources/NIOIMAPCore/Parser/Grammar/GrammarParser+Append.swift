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
    // append          = "APPEND" SP mailbox 1*append-message
    static func parseAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStream {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> CommandStream in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try PL.fixedString(" APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .append(.start(tag: tag, appendingTo: mailbox))
        }
    }

    // append-data = literal / literal8 / append-data-ext
    static func parseAppendData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendData {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AppendData in
            let withoutContentTransferEncoding = try PL.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.fixedString("~", buffer: &buffer, tracker: tracker)
            }.map { () in true } ?? false
            try PL.fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            _ = try PL.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.fixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try PL.fixedString("}", buffer: &buffer, tracker: tracker)
            try PL.newline(buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, withoutContentTransferEncoding: withoutContentTransferEncoding)
        }
    }

    // append-message = appents-opts SP append-data
    static func parseAppendMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendMessage {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // Like appendMessage, but with CATENATE at the start instead of regular append data.
    static func parseCatenateMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOptions {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendOptions in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.fixedString("CATENATE (", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    enum AppendOrCatenateMessage {
        case append(AppendMessage)
        case catenate(AppendOptions)
    }

    static func parseAppendOrCatenateMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
        func parseAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .append(self.parseAppendMessage(buffer: &buffer, tracker: tracker))
        }

        func parseCatenate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .catenate(self.parseCatenateMessage(buffer: &buffer, tracker: tracker))
        }

        return try PL.oneOf(
            parseCatenate,
            parseAppend,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    static func parseAppendOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOptions {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList = try PL.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseFlagList(buffer: &buffer, tracker: tracker)
            } ?? []
            let internalDate = try PL.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> InternalDate in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseInternalDate(buffer: &buffer, tracker: tracker)
            }
            var kvs = KeyValues<String, ParameterValue>()
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) { (buffer, tracker) -> KeyValue<String, ParameterValue> in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
            }
            return .init(flagList: flagList, internalDate: internalDate, extensions: kvs)
        }
    }

    enum CatenatePart {
        case url(ByteBuffer)
        case text(Int)
        case end
    }

    static func parseCatenatePart(expectPrecedingSpace: Bool, buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
        func parseCatenateURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            }
            try PL.fixedString("URL ", buffer: &buffer, tracker: tracker)
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .url(url)
        }

        func parseCatenateText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            }
            try PL.fixedString("TEXT {", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            _ = try PL.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try PL.fixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try PL.fixedString("}", buffer: &buffer, tracker: tracker)
            try PL.newline(buffer: &buffer, tracker: tracker)
            return .text(length)
        }

        func parseCatenateEnd(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            try PL.fixedString(")", buffer: &buffer, tracker: tracker)
            return .end
        }

        return try PL.oneOf(
            parseCatenateURL,
            parseCatenateText,
            parseCatenateEnd,
            buffer: &buffer,
            tracker: tracker
        )
    }
}
