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
    // mailbox         = "INBOX" / astring
    func parseMailbox(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxName {
        MailboxName(try self.parseAString(buffer: &buffer, tracker: tracker))
    }

    // mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
    //                    esearch-response /
    //                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
    //                    number SP "EXISTS" / Namespace-Response
    func parseMailboxData(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
        /// Parse those sub-parses that have a fixed text prefix.
        func parseMailboxData_withFixedPrefix(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
            func parseMailboxData_flags(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                try buffer.parseSpaces()
                return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
            }

            func parseMailboxData_list(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                try buffer.parseSpaces()
                return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
            }

            func parseMailboxData_lsub(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                try buffer.parseSpaces()
                return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
            }

            func parseMailboxData_extendedSearch(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData
            {
                let response = try self.parseExtendedSearchResponse(buffer: &buffer, tracker: tracker)
                return .extendedSearch(response)
            }

            func parseMailboxData_search(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                let identifiers = try buffer.parseZeroOrMore(tracker: tracker) {
                    (buffer, tracker) -> UnknownMessageIdentifier in
                    try buffer.parseSpaces()
                    let num = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                    guard let id = UnknownMessageIdentifier(exactly: num) else {
                        throw ParserError(dynamicHint: "Can't make unknown message identfiier from \(num)")
                    }
                    return id
                }
                let modificationSequence = try buffer.parseOptional(tracker: tracker) {
                    (buffer, tracker) -> ModificationSequenceValue in
                    try buffer.parseSpaces()
                    return try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
                }
                return .search(identifiers, modificationSequence)
            }

            func parseMailboxData_status(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                try buffer.parseSpaces()
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                try buffer.matchFixed("(")
                let status = try buffer.parseOptional(tracker: tracker, parser: self.parseMailboxStatus)
                try buffer.matchFixed(")")
                return .status(mailbox, status ?? .init())
            }

            func parseMailboxData_namespace(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
            }

            func parseMailboxData_sort(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
                let identifiers = try buffer.parseZeroOrMore(tracker: tracker) {
                    (buffer, tracker) -> UnknownMessageIdentifier in
                    try buffer.parseSpaces()
                    let num = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                    guard let id = UnknownMessageIdentifier(exactly: num) else {
                        throw ParserError(dynamicHint: "Can't make unknown message identfiier from \(num)")
                    }
                    return id
                }
                let modificationSequence = try buffer.parseOptional(tracker: tracker) {
                    (buffer, tracker) -> ModificationSequenceValue in
                    try buffer.parseSpaces()
                    return try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
                }
                return .sort(identifiers, modificationSequence)
            }

            func parseMailboxData_uidBatchesResponse(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> MailboxData {
                .uidBatches(try self.parseUIDBatchesResponse(buffer: &buffer, tracker: tracker))
            }

            return try self.selectingKeyword(buffer: &buffer) { keyword, buffer in
                switch keyword {
                case "FLAGS": return try parseMailboxData_flags(buffer: &buffer, tracker: tracker)
                case "LIST": return try parseMailboxData_list(buffer: &buffer, tracker: tracker)
                case "LSUB": return try parseMailboxData_lsub(buffer: &buffer, tracker: tracker)
                case "ESEARCH":
                    return try parseMailboxData_extendedSearch(buffer: &buffer, tracker: tracker)
                case "SEARCH": return try parseMailboxData_search(buffer: &buffer, tracker: tracker)
                case "SORT": return try parseMailboxData_sort(buffer: &buffer, tracker: tracker)
                case "STATUS": return try parseMailboxData_status(buffer: &buffer, tracker: tracker)
                case "NAMESPACE":
                    return try parseMailboxData_namespace(buffer: &buffer, tracker: tracker)
                case "UIDBATCHES":
                    return try parseMailboxData_uidBatchesResponse(buffer: &buffer, tracker: tracker)
                default: throw ParserError(hint: "Not a mailbox-data keyword")
                }
            }
        }

        func parseMailboxData_exists(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" EXISTS")
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxData {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" RECENT")
            return .recent(number)
        }

        return try buffer.parseOneOf(
            [
                { try parseMailboxData_withFixedPrefix(buffer: &$0, tracker: $1) },
                { try parseMailboxData_exists(buffer: &$0, tracker: $1) },
                { try parseMailboxData_recent(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    /// Parses a `MAILBOXID` value leniently: if the server sends an invalid ID, it is consumed and `nil` is returned
    /// rather than failing the parse. Callers map `nil` to their `.invalid` case.
    func parseMailboxIDLeniently(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxID? {
        try parseObjectIDLeniently(buffer: &buffer, tracker: tracker).map(MailboxID.init)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    func parseMailboxList(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxInfo {
        func parseMailboxList_quotedChar_some(buffer: inout ParseInput, tracker: StackTracker) throws -> Character? {
            try buffer.composite(tracker: tracker) { (buffer, tracker) -> Character? in
                try buffer.matchFixed("\"")

                // QUOTED-CHAR = <any TEXT-CHAR except quoted-specials> / "\" quoted-specials
                var character = try buffer.readByte()
                if character == UInt8(ascii: "\\") {
                    character = try buffer.readByte()
                    guard character.isQuotedSpecial else {
                        throw ParserError(
                            dynamicHint:
                                "Expected quoted special found \(String(decoding: [character], as: Unicode.UTF8.self))"
                        )
                    }
                } else {
                    guard character.isQuotedChar else {
                        throw ParserError(
                            dynamicHint: "Expected quoted char found \(String(decoding: [character], as: Unicode.UTF8.self))"
                        )
                    }
                }

                try buffer.matchFixed("\"")
                return Character(UnicodeScalar(character))
            }
        }

        func parseMailboxList_quotedChar_nil(buffer: inout ParseInput, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker -> MailboxInfo in
            try buffer.matchFixed("(")
            let flags =
                try buffer.parseOptional(tracker: tracker, parser: self.parseMailboxListFlags) ?? []
            try buffer.matchFixed(")")
            try buffer.parseSpaces()
            let character = try buffer.parseOneOf(
                { try parseMailboxList_quotedChar_some(buffer: &$0, tracker: $1) },
                { try parseMailboxList_quotedChar_nil(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let listExtended =
                try buffer.parseOptional(
                    tracker: tracker,
                    parser: { (buffer, tracker) -> ListExtended in
                        try buffer.parseSpaces()
                        return try self.parseMailboxListExtended(buffer: &buffer, tracker: tracker)
                    }
                ) ?? ListExtended()
            return MailboxInfo(
                attributes: flags,
                path: try .init(name: mailbox, pathSeparator: character),
                objectID: listExtended.objectID,
                extensions: listExtended.extensions
            )
        }
    }

    struct ListExtended {
        var objectID: CompoundObjectID?
        var extensions = OrderedDictionary<[UInt8], ParameterValue>()
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    func parseMailboxListExtended(buffer: inout ParseInput, tracker: StackTracker) throws -> ListExtended {
        try buffer.composite(tracker: tracker) { buffer, tracker -> ListExtended in
            try buffer.matchFixed("(")
            var items: [MailboxListExtendedItem] = []
            if let first = try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseMailboxListExtendedItem
            ) {
                items.append(first)
                try buffer.parseZeroOrMore(into: &items, tracker: tracker) {
                    (buffer, tracker) -> MailboxListExtendedItem in
                    try buffer.parseSpaces()
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
            }
            try buffer.matchFixed(")")

            var result = ListExtended()
            for item in items {
                switch item {
                case .objectID(let compound):
                    result.objectID = compound
                case .other(let kv):
                    result.extensions[kv.key] = kv.value
                }
            }
            return result
        }
    }

    enum MailboxListExtendedItem {
        case objectID(CompoundObjectID)
        case other(KeyValue<[UInt8], ParameterValue>)
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    // objectid-extended-item  =  "OBJECTID" SP objectid-compound-value
    //                            ; the tag may be quoted, per mbox-list-extended-item-tag
    func parseMailboxListExtendedItem(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws -> MailboxListExtendedItem {
        try buffer.composite(tracker: tracker) { buffer, tracker -> MailboxListExtendedItem in
            let tag = try self.parseAString(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            if String(decoding: tag, as: UTF8.self).uppercased() == "OBJECTID" {
                return .objectID(try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker))
            }
            let val = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .other(.init(key: tag, value: val))
        }
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    func parseMailboxListFlags(buffer: inout ParseInput, tracker: StackTracker) throws -> [MailboxInfo.Attribute] {
        // `flag-extension` is `"\" atom`, the same production `Attribute` validates.
        var results = [MailboxInfo.Attribute(unchecked: try self.parseFlagExtension(buffer: &buffer, tracker: tracker))]
        do {
            while true {
                let mark = buffer.consumed
                try buffer.parseSpaces()
                let att = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
                results.append(.init(unchecked: att))
                try buffer.requireProgress(since: mark)
            }
        } catch is ParserError {
            // The list ends at the first flag that does not parse.
        }
        return results
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    func parseMailboxStatus(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxStatus {
        enum MailboxValue: Hashable {
            case messages(Int)
            case uidNext(UID)
            case uidValidity(UIDValidity)
            case unseen(Int)
            case size(Int)
            case recent(Int)
            case highestModifierSequence(ModificationSequenceValue)
            case appendLimit(Int?)
            case mailboxID(MailboxStatus.MailboxID)
            case objectID(CompoundObjectID)
        }

        func parseStatusAttributeValue_messages(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue
        {
            try buffer.matchFixed("MESSAGES ")
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue {
            try buffer.matchFixed("UIDNEXT ")
            return .uidNext(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> MailboxValue {
            try buffer.matchFixed("UIDVALIDITY ")
            return .uidValidity(try self.parseUIDValidity(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue {
            try buffer.matchFixed("UNSEEN ")
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue {
            try buffer.matchFixed("SIZE ")
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modificationSequence(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> MailboxValue {
            try buffer.matchFixed("HIGHESTMODSEQ ")
            return .highestModifierSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_recent(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue {
            try buffer.matchFixed("RECENT ")
            return .recent(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_appendLimit(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> MailboxValue {
            try buffer.matchFixed("APPENDLIMIT ")

            func parseStatusAttributeValue_appendLimit_nil(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> MailboxValue {
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return .appendLimit(nil)
            }
            func parseStatusAttributeValue_appendLimit_number(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws -> MailboxValue {
                return .appendLimit(try self.parseNumber(buffer: &buffer, tracker: tracker))
            }

            return try buffer.parseOneOf(
                [
                    { try parseStatusAttributeValue_appendLimit_nil(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_appendLimit_number(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        func parseStatusAttributeValue_mailboxID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> MailboxValue {
            try buffer.matchFixed("MAILBOXID (")
            let mailboxID = try self.parseMailboxIDLeniently(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return .mailboxID(.init(mailboxID))
        }

        func parseStatusAttributeValue_objectID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws -> MailboxValue {
            try buffer.matchFixed("OBJECTID ")
            return .objectID(try self.parseCompoundObjectID(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxValue {
            try buffer.parseOneOf(
                [
                    { try parseStatusAttributeValue_messages(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_uidnext(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_uidvalidity(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_unseen(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_size(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_modificationSequence(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_recent(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_appendLimit(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_mailboxID(buffer: &$0, tracker: $1) },
                    { try parseStatusAttributeValue_objectID(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) -> MailboxStatus in

            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) -> MailboxValue in
                try buffer.parseSpaces()
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
                case .appendLimit(let limit):
                    status.appendLimit = limit
                case .mailboxID(let id):
                    status.mailboxID = id
                case .objectID(let compound):
                    status.objectID = compound
                }
            }
            return status
        }
    }

    // mbox-or-pat  = list-mailbox / patterns
    func parseMailboxPatterns(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxPatterns_list(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxPatterns_patterns(buffer: inout ParseInput, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            { try parseMailboxPatterns_list(buffer: &$0, tracker: $1) },
            { try parseMailboxPatterns_patterns(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }
}
