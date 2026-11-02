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
    // search-program     = ["CHARSET" SP charset SP]
    //                         search-key *(SP search-key)
    //                         ;; CHARSET argument to SEARCH MUST be
    //                         ;; registered with IANA.
    func parseSearchProgram(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (CharacterSetName?, SearchKey) {
        let charset = try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> CharacterSetName in
            try buffer.matchFixed("CHARSET ")
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            return charset
        }
        var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
        try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
            try buffer.parseSpaces()
            return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
        }

        if case .and = array.first!, array.count == 1 {
            return (charset, array.first!)
        } else if array.count == 1 {
            return (charset, array.first!)
        } else {
            return (charset, .and(array))
        }
    }

    // RFC 7377
    // one-correlator =  ("TAG" SP tag-string) / ("MAILBOX" SP astring) /
    //                      ("UIDVALIDITY" SP nz-number)
    //                      ; Each correlator MUST appear exactly once.
    // search-correlator =  SP "(" one-correlator *(SP one-correlator) ")"
    func parseSearchCorrelator(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchCorrelator {
        var tag: String?
        var mailbox: MailboxName?
        var uidValidity: UIDValidity?

        func parseSearchCorrelator_tag(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            // tag-string = string
            try buffer.matchFixed("TAG ")
            tag = try decodeUTF8(self.parseString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchCorrelator_mailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try buffer.matchFixed("MAILBOX ")
            mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_uidValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try buffer.matchFixed("UIDVALIDITY ")
            uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_once(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try buffer.parseOneOf(
                { try parseSearchCorrelator_tag(buffer: &$0, tracker: $1) },
                { try parseSearchCorrelator_mailbox(buffer: &$0, tracker: $1) },
                { try parseSearchCorrelator_uidValidity(buffer: &$0, tracker: $1) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")

            try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
            var result: SearchCorrelator
            if try buffer.parseOptional(tracker: tracker, parser: { input, _ in try input.parseSpaces() }) != nil {
                // If we have 2, we must have the third.
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                guard let tag = tag, mailbox != nil, uidValidity != nil else {
                    throw ParserError(hint: "Not all components present for SearchCorrelator")
                }
                result = SearchCorrelator(tag: tag, mailbox: mailbox, uidValidity: uidValidity)
            } else {
                guard let tag = tag else {
                    throw ParserError(hint: "tag missing for SearchCorrelator")
                }
                result = SearchCorrelator(tag: tag)
            }

            try buffer.matchFixed(")")
            return result
        }
    }

    // search-critera = search-key *(search-key)
    func parseSearchCriteria(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) in
                try buffer.parseSpaces()
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // search-key      = "ALL" / "ANSWERED" / "BCC" SP astring /
    //                   "BEFORE" SP date / "BODY" SP astring /
    //                   "CC" SP astring / "DELETED" / "FLAGGED" /
    //                   "FROM" SP astring / "KEYWORD" SP flag-keyword /
    //                   "NEW" / "OLD" / "ON" SP date / "RECENT" / "SEEN" /
    //                   "SINCE" SP date / "SUBJECT" SP astring /
    //                   "TEXT" SP astring / "TO" SP astring /
    //                   "UNANSWERED" / "UNDELETED" / "UNFLAGGED" /
    //                   "UNKEYWORD" SP flag-keyword / "UNSEEN" /
    //                   "DRAFT" / "HEADER" SP header-fld-name SP astring /
    //                   "LARGER" SP number / "NOT" SP search-key /
    //                   "OR" SP search-key SP search-key /
    //                   "SENTBEFORE" SP date / "SENTON" SP date /
    //                   "SENTSINCE" SP date / "SMALLER" SP number /
    //                   "UID" SP sequence-set / "UNDRAFT" / sequence-set /
    //                   "(" search-key *(SP search-key) ")"
    func parseSearchKey(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
        func parseSearchKey_fixed(
            string: String,
            result: SearchKey,
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchKey {
            try buffer.matchFixed(string)
            return result
        }

        func parseSearchKey_fixedOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            let inputs: [(String, SearchKey)] = [
                ("ALL", .all),
                ("ANSWERED", .answered),
                ("DELETED", .deleted),
                ("FLAGGED", .flagged),
                ("NEW", .new),
                ("OLD", .old),
                ("RECENT", .recent),
                ("SEEN", .seen),
                ("UNSEEN", .unseen),
                ("UNANSWERED", .unanswered),
                ("UNDELETED", .undeleted),
                ("UNFLAGGED", .unflagged),
                ("DRAFT", .draft),
                ("UNDRAFT", .undraft),
            ]
            let save = buffer
            for (key, value) in inputs {
                do {
                    return try parseSearchKey_fixed(string: key, result: value, buffer: &buffer, tracker: tracker)
                } catch is ParserError {
                    buffer = save
                }
            }
            throw ParserError()
        }

        func parseSearchKey_bcc(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("BCC ")
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("BEFORE ")
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("BODY ")
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("CC ")
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("FROM ")
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("KEYWORD ")
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("ON ")
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SINCE ")
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SUBJECT ")
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("TEXT ")
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("TO ")
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("UNKEYWORD ")
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("FILTER ")
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("HEADER ")
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("LARGER ")
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SMALLER ")
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("NOT ")
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("OR ")
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SENTBEFORE ")
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SENTON ")
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("SENTSINCE ")
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("UID ")
            return .uid(
                try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            )
        }

        func parseSearchKey_uidAfter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("UIDAFTER ")
            return .uidAfter(
                try self.parseLastCommandMessageID(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: self.parseMessageIdentifier
                )
            )
        }

        func parseSearchKey_uidBefore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("UIDBEFORE ")
            return .uidBefore(
                try self.parseLastCommandMessageID(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: self.parseMessageIdentifier
                )
            )
        }

        func parseSearchKey_sequenceSet(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceNumbers(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("(")
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try buffer.parseSpaces()
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")

            guard array.count == 1 else {
                return .and(array)
            }
            return array.first!
        }

        func parseSearchKey_older(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("OLDER ")
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("YOUNGER ")
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_modificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            .modificationSequence(try self.parseSearchModificationSequence(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_emailID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("EMAILID ")
            let objectID = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .emailID(EmailID(objectID))
        }

        func parseSearchKey_threadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("THREADID ")
            let objectID = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .threadID(ThreadID(objectID))
        }

        func parseSearchKey_gmailMessageID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("X-GM-MSGID ")
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseSearchKey_gmailThreadID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("X-GM-THRID ")
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseSearchKey_gmailRaw(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try buffer.matchFixed("X-GM-RAW ")
            return .gmailRaw(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseSearchKey_older(buffer: &$0, tracker: $1) },
                { try parseSearchKey_fixedOptions(buffer: &$0, tracker: $1) },
                { try parseSearchKey_younger(buffer: &$0, tracker: $1) },
                { try parseSearchKey_bcc(buffer: &$0, tracker: $1) },
                { try parseSearchKey_before(buffer: &$0, tracker: $1) },
                { try parseSearchKey_body(buffer: &$0, tracker: $1) },
                { try parseSearchKey_cc(buffer: &$0, tracker: $1) },
                { try parseSearchKey_from(buffer: &$0, tracker: $1) },
                { try parseSearchKey_keyword(buffer: &$0, tracker: $1) },
                { try parseSearchKey_on(buffer: &$0, tracker: $1) },
                { try parseSearchKey_since(buffer: &$0, tracker: $1) },
                { try parseSearchKey_subject(buffer: &$0, tracker: $1) },
                { try parseSearchKey_text(buffer: &$0, tracker: $1) },
                { try parseSearchKey_to(buffer: &$0, tracker: $1) },
                { try parseSearchKey_unkeyword(buffer: &$0, tracker: $1) },
                { try parseSearchKey_header(buffer: &$0, tracker: $1) },
                { try parseSearchKey_larger(buffer: &$0, tracker: $1) },
                { try parseSearchKey_smaller(buffer: &$0, tracker: $1) },
                { try parseSearchKey_not(buffer: &$0, tracker: $1) },
                { try parseSearchKey_or(buffer: &$0, tracker: $1) },
                { try parseSearchKey_sentBefore(buffer: &$0, tracker: $1) },
                { try parseSearchKey_sentOn(buffer: &$0, tracker: $1) },
                { try parseSearchKey_sentSince(buffer: &$0, tracker: $1) },
                { try parseSearchKey_uid(buffer: &$0, tracker: $1) },
                { try parseSearchKey_uidAfter(buffer: &$0, tracker: $1) },
                { try parseSearchKey_uidBefore(buffer: &$0, tracker: $1) },
                { try parseSearchKey_sequenceSet(buffer: &$0, tracker: $1) },
                { try parseSearchKey_array(buffer: &$0, tracker: $1) },
                { try parseSearchKey_filter(buffer: &$0, tracker: $1) },
                { try parseSearchKey_modificationSequence(buffer: &$0, tracker: $1) },
                { try parseSearchKey_emailID(buffer: &$0, tracker: $1) },
                { try parseSearchKey_threadID(buffer: &$0, tracker: $1) },
                { try parseSearchKey_gmailMessageID(buffer: &$0, tracker: $1) },
                { try parseSearchKey_gmailThreadID(buffer: &$0, tracker: $1) },
                { try parseSearchKey_gmailRaw(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    func parseSearchModificationSequence(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> SearchModificationSequence {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> SearchModificationSequence in
            try buffer.matchFixed("MODSEQ")
            var extensions = OrderedDictionary<EntryFlagName, EntryKindRequest>()
            try buffer.parseZeroOrMore(
                into: &extensions,
                tracker: tracker,
                parser: self.parseSearchModificationSequenceExtension
            )
            try buffer.parseSpaces()
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(extensions: extensions, sequenceValue: val)
        }
    }

    func parseSearchModificationSequenceExtension(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<EntryFlagName, EntryKindRequest> {
        try buffer.composite(tracker: tracker) {
            (buffer, tracker) -> KeyValue<EntryFlagName, EntryKindRequest> in
            try buffer.parseSpaces()
            let flag = try self.parseEntryFlagName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let request = try self.parseEntryKindRequest(buffer: &buffer, tracker: tracker)
            return .init(key: flag, value: request)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    func parseSearchReturnDataExtension(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<ExtensionKey<SearchReturnData>, ParameterValue> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker -> KeyValue<ExtensionKey<SearchReturnData>, ParameterValue> in
            let modifier: ExtensionKey<SearchReturnData> =
                try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: modifier, value: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     "PARTIAL" SP "(" partial-range SP partial-results ")"
    //                     search-ret-data-ext
    func parseSearchReturnData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try buffer.matchFixed("MIN ")
            return .min(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try buffer.matchFixed("MAX ")
            return .max(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try buffer.matchFixed("ALL ")
            return .all(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try buffer.matchFixed("COUNT ")
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_modificationSequence(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchReturnData {
            try buffer.matchFixed("MODSEQ ")
            return .modificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_partial(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData
        {
            func parseSearchReturnData_partial_set(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageIdentifierSet<UnknownMessageIdentifier> {
                try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker).set
            }

            func parseSearchReturnData_partial_nil(
                buffer: inout ParseBuffer,
                tracker: StackTracker
            ) throws -> MessageIdentifierSet<UnknownMessageIdentifier> {
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return []
            }

            try buffer.matchFixed("PARTIAL (")
            let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let identifiers = try buffer.parseOneOf(
                [
                    { try parseSearchReturnData_partial_set(buffer: &$0, tracker: $1) },
                    { try parseSearchReturnData_partial_nil(buffer: &$0, tracker: $1) },
                ],
                tracker: tracker
            )
            try buffer.matchFixed(")")
            return .partial(range, identifiers)
        }

        func parseSearchReturnData_dataExtension(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try buffer.parseOneOf(
            [
                { try parseSearchReturnData_min(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_max(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_all(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_count(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_modificationSequence(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_partial(buffer: &$0, tracker: $1) },
                { try parseSearchReturnData_dataExtension(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    func parseSearchReturnOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) in
            try buffer.matchFixed(" RETURN (")
            let array =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                    var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                    try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                        (buffer, tracker) -> SearchReturnOption in
                        try buffer.parseSpaces()
                        return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                    }
                    return array
                } ?? []
            try buffer.matchFixed(")")
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      "PARTIAL" SP partial-range
    //                      search-ret-opt-ext
    func parseSearchReturnOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption
        {
            try buffer.matchFixed("MIN")
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption
        {
            try buffer.matchFixed("MAX")
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption
        {
            try buffer.matchFixed("ALL")
            return .all
        }

        func parseSearchReturnOption_count(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchReturnOption {
            try buffer.matchFixed("COUNT")
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption
        {
            try buffer.matchFixed("SAVE")
            return .save
        }

        func parseSearchReturnOption_partial(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchReturnOption {
            try buffer.matchFixed("PARTIAL")
            try buffer.parseSpaces()
            let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
            return .partial(range)
        }

        func parseSearchReturnOption_extension(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try buffer.parseOneOf(
            [
                { try parseSearchReturnOption_min(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_max(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_all(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_count(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_save(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_partial(buffer: &$0, tracker: $1) },
                { try parseSearchReturnOption_extension(buffer: &$0, tracker: $1) },
            ],
            tracker: tracker
        )
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    func parseSearchReturnOptionExtension(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> KeyValue<ExtensionKey<SearchReturnOption>, ParameterValue?> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker -> KeyValue<ExtensionKey<SearchReturnOption>, ParameterValue?> in
            let name: ExtensionKey<SearchReturnOption> = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) -> ParameterValue in
                try buffer.parseSpaces()
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: params)
        }
    }

    func parseSearchSortModificationSequence(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> ModificationSequenceValue {
        try buffer.composite(tracker: tracker) { (buffer, tracker) -> ModificationSequenceValue in
            try buffer.matchFixed("(MODSEQ ")
            let modSeq = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return modSeq
        }
    }
}
