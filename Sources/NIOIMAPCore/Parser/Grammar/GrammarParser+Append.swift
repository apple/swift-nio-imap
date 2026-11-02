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

import struct OrderedCollections.OrderedDictionary

extension GrammarParser {
    // append          = "APPEND" SP mailbox 1*append-message
    func parseAppend(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CommandStreamPart {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> CommandStreamPart in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" APPEND ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .append(.start(tag: tag, appendingTo: mailbox))
        }
    }

    // append-data = literal / literal8 / append-data-ext
    func parseAppendData(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AppendData {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> AppendData in
            let withoutContentTransferEncoding =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                    try buffer.matchFixed("~")
                }.map { () in true } ?? false
            try buffer.matchFixed("{")
            let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
            _ =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                    try buffer.matchFixed("+")
                }.map { () in false } ?? true
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            return .init(byteCount: length, withoutContentTransferEncoding: withoutContentTransferEncoding)
        }
    }

    // append-message = appents-opts SP append-data
    func parseAppendMessage(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AppendMessage {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // Like appendMessage, but with CATENATE at the start instead of regular append data.
    func parseCatenateMessage(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AppendOptions {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> AppendOptions in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            try buffer.matchFixed("CATENATE (")
            return options
        }
    }

    enum AppendOrCatenateMessage {
        case append(AppendMessage)
        case catenate(AppendOptions)
    }

    func parseAppendOrCatenateMessage(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> AppendOrCatenateMessage {
        func parseAppend(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> AppendOrCatenateMessage {
            try .append(self.parseAppendMessage(buffer: &buffer, tracker: tracker))
        }

        func parseCatenate(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> AppendOrCatenateMessage {
            try .catenate(self.parseCatenateMessage(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseCatenate(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseAppend(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    func parseAppendOptions(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> AppendOptions {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let flagList =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> [Flag] in
                    try buffer.parseSpaces()
                    return try self.parseFlagList(buffer: &buffer, tracker: tracker)
                } ?? []
            let internalDate = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ServerMessageDate in
                try buffer.parseSpaces()
                return try self.parseInternalDate(buffer: &buffer, tracker: tracker)
            }
            var kvs = OrderedDictionary<ExtensionKey<AppendOptions>, ParameterValue>()
            try buffer.parseZeroOrMore(into: &kvs, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> KeyValue<ExtensionKey<AppendOptions>, ParameterValue> in
                try buffer.parseSpaces()
                return try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
            }
            return .init(flagList: flagList, internalDate: internalDate, extensions: kvs)
        }
    }

    enum CatenatePart {
        case url([UInt8])
        case text(Int)
        case end
    }

    func parseCatenatePart(
        expectPrecedingSpace: Bool,
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> CatenatePart {
        func parseCatenateURL(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CatenatePart {
            if expectPrecedingSpace {
                try buffer.parseSpaces()
            }
            try buffer.matchFixed("URL ")
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .url(url)
        }

        func parseCatenateText(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CatenatePart {
            if expectPrecedingSpace {
                try buffer.parseSpaces()
            }
            try buffer.matchFixed("TEXT {")
            let length = try self.parseNumber(buffer: &buffer, tracker: tracker)
            _ =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
                    try buffer.matchFixed("+")
                }.map { () in false } ?? true
            try buffer.matchFixed("}")
            try buffer.matchNewline()
            return .text(length)
        }

        func parseCatenateEnd(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> CatenatePart {
            try buffer.matchFixed(")")
            return .end
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseCatenateURL(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseCatenateText(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseCatenateEnd(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }
}
