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
    // mailbox         = "INBOX" / astring
    static func parseMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return MailboxName(string)
    }

    // mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
    //                    esearch-response /
    //                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
    //                    number SP "EXISTS" / Namespace-Response
    static func parseMailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
        func parseMailboxData_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("FLAGS ", buffer: &buffer, tracker: tracker)
            return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("LIST ", buffer: &buffer, tracker: tracker)
            return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_lsub(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("LSUB ", buffer: &buffer, tracker: tracker)
            return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_esearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            let response = try self.parseEsearchResponse(buffer: &buffer, tracker: tracker)
            return .esearch(response)
        }

        func parseMailboxData_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let nums = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return .search(nums)
        }

        func parseMailboxData_searchSort(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            })
            try space(buffer: &buffer, tracker: tracker)
            let seq = try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
            return .searchSort(.init(identifiers: array, modificationSequence: seq))
        }

        func parseMailboxData_status(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            try fixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let status = try optional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxStatus)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, status ?? .init())
        }

        func parseMailboxData_exists(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" EXISTS", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" RECENT", buffer: &buffer, tracker: tracker)
            return .recent(number)
        }

        func parseMailboxData_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxData {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxData_flags,
            parseMailboxData_list,
            parseMailboxData_lsub,
            parseMailboxData_esearch,
            parseMailboxData_status,
            parseMailboxData_exists,
            parseMailboxData_recent,
            parseMailboxData_searchSort,
            parseMailboxData_search,
            parseMailboxData_namespace,
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    static func parseMailboxList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxInfo {
        func parseMailboxList_quotedChar_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Character? in
                try fixedString("\"", buffer: &buffer, tracker: tracker)

                guard let character = buffer.readSlice(length: 1)?.readableBytesView.first else {
                    throw _IncompleteMessage()
                }
                guard character.isQuotedChar else {
                    throw ParserError(hint: "Expected quoted char found \(String(decoding: [character], as: Unicode.UTF8.self))")
                }

                try fixedString("\"", buffer: &buffer, tracker: tracker)
                return Character(UnicodeScalar(character))
            }
        }

        func parseMailboxList_quotedChar_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxInfo in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try optional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxListFlags) ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let character = try oneOf([
                parseMailboxList_quotedChar_some,
                parseMailboxList_quotedChar_nil,
            ], buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let listExtended = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> [ListExtendedItem] in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListExtended(buffer: &buffer, tracker: tracker)
            }) ?? []
            return MailboxInfo(attributes: flags, path: try .init(name: mailbox, pathSeparator: character), extensions: listExtended)
        }
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    static func parseMailboxListExtended(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListExtendedItem] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListExtendedItem] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let data = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ListExtendedItem] in
                var array = [try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListExtendedItem in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    static func parseMailboxListExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListExtendedItem {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListExtendedItem in
            let tag = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let val = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return ListExtendedItem(tag: tag, extensionValue: val)
        }
    }

    // mbox-or-pat =  list-mailbox / patterns
    static func parseMailboxOrPat(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxOrPat_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxOrPat_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxOrPat_list,
            parseMailboxOrPat_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    static func parseMailboxListFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxInfo.Attribute] {
        var results = [MailboxInfo.Attribute(try self.parseFlagExtension(buffer: &buffer, tracker: tracker))]
        do {
            while true {
                try space(buffer: &buffer, tracker: tracker)
                let att = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
                results.append(.init(att))
            }
        } catch {
            // do nothing
        }
        return results
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    static func parseMailboxStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxStatus {
        enum MailboxValue: Equatable {
            case messages(Int)
            case uidNext(UID)
            case uidValidity(UIDValidity)
            case unseen(Int)
            case size(Int)
            case recent(Int)
            case highestModifierSequence(ModificationSequenceValue)
        }

        func parseStatusAttributeValue_messages(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("MESSAGES ", buffer: &buffer, tracker: tracker)
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseUIDValidity(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("SIZE ", buffer: &buffer, tracker: tracker)
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .highestModifierSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("RECENT ", buffer: &buffer, tracker: tracker)
            return .recent(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try oneOf([
                parseStatusAttributeValue_messages,
                parseStatusAttributeValue_uidnext,
                parseStatusAttributeValue_uidvalidity,
                parseStatusAttributeValue_unseen,
                parseStatusAttributeValue_size,
                parseStatusAttributeValue_modificationSequence,
                parseStatusAttributeValue_recent,
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MailboxStatus in

            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxValue in
                try space(buffer: &buffer, tracker: tracker)
                return try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)
            }

            var status = MailboxStatus()
            for value in array {
                switch value {
                case .messages(let messages):
                    status.messageCount = messages
                case .highestModifierSequence(let modSequence):
                    status.highestModificationSequence = modSequence
                case .size(let size):
                    status.size = size
                case .uidNext(let uidNext):
                    status.nextUID = uidNext
                case .uidValidity(let uidValidity):
                    status.uidValidity = uidValidity
                case .unseen(let unseen):
                    status.unseenCount = unseen
                case .recent(let recent):
                    status.recentCount = recent
                }
            }
            return status
        }
    }

    // mbox-or-pat  = list-mailbox / patterns
    static func parseMailboxPatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxPatterns_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxPatterns_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxPatterns_list,
            parseMailboxPatterns_patterns,
        ], buffer: &buffer, tracker: tracker)
    }
}
