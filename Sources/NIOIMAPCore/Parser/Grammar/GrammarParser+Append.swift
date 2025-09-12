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
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    // append          = "APPEND" SP mailbox 1*append-message
    func parseAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CommandStreamPart {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> CommandStreamPart in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .append(.start(tag: tag, appendingTo: mailbox))
        }
    }

    // append-data = literal / literal8 / append-data-ext
    func parseAppendData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendData {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AppendData in
            let withoutContentTransferEncoding =
                try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                    try PL.parseFixedString("~", buffer: &buffer, tracker: tracker)
                }.map { () in true } ?? false
            try PL.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
            _ =
                try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                    try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
                }.map { () in false } ?? true
            try PL.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, withoutContentTransferEncoding: withoutContentTransferEncoding)
        }
    }

    // append-message = appents-opts SP append-data
    func parseAppendMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendMessage {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // Like appendMessage, but with CATENATE at the start instead of regular append data.
    func parseCatenateMessage(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOptions {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendOptions in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("CATENATE (", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    enum AppendOrCatenateMessage {
        case append(AppendMessage)
        case catenate(AppendOptions)
    }

    func parseAppendOrCatenateMessage(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> AppendOrCatenateMessage {
        func parseAppend(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .append(self.parseAppendMessage(buffer: &buffer, tracker: tracker))
        }

        func parseCatenate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .catenate(self.parseCatenateMessage(buffer: &buffer, tracker: tracker))
        }

        return try PL.parseOneOf(
            parseCatenate,
            parseAppend,
            buffer: &buffer,
            tracker: tracker
        )
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    func parseAppendOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> AppendOptions {
        try PL.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList =
                try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                    try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagList(buffer: &buffer, tracker: tracker)
                } ?? []
            let internalDate = try PL.parseOptional(buffer: &buffer, tracker: tracker) {
                (buffer, tracker) -> ServerMessageDate in
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseInternalDate(buffer: &buffer, tracker: tracker)
            }
            var kvs = OrderedDictionary<String, ParameterValue>()
            try PL.parseZeroOrMore(buffer: &buffer, into: &kvs, tracker: tracker) {
                (buffer, tracker) -> KeyValue<String, ParameterValue> in
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

    func parseCatenatePart(
        expectPrecedingSpace: Bool,
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> CatenatePart {
        func parseCatenateURL(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString("URL ", buffer: &buffer, tracker: tracker)
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .url(url)
        }

        func parseCatenateText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            }
            try PL.parseFixedString("TEXT {", buffer: &buffer, tracker: tracker)
            let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
            _ =
                try PL.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                    try PL.parseFixedString("+", buffer: &buffer, tracker: tracker)
                }.map { () in false } ?? true
            try PL.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try PL.parseNewline(buffer: &buffer, tracker: tracker)
            return .text(length)
        }

        func parseCatenateEnd(buffer: inout ParseBuffer, tracker: StackTracker) throws -> CatenatePart {
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .end
        }

        return try PL.parseOneOf(
            parseCatenateURL,
            parseCatenateText,
            parseCatenateEnd,
            buffer: &buffer,
            tracker: tracker
        )
    }
}
