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
    // search-program     = ["CHARSET" SP charset SP]
    //                         search-key *(SP search-key)
    //                         ;; CHARSET argument to SEARCH MUST be
    //                         ;; registered with IANA.
    func parseSearchProgram(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> (CharacterSetName?, SearchKey) {
        let charset = try buffer.parseOptional(tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> CharacterSetName in
            try buffer.matchFixed("CHARSET ")
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            return charset
        }
        var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
        try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> SearchKey in
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
    func parseSearchCorrelator(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SearchCorrelator {
        var tag: String?
        var mailbox: MailboxName?
        var uidValidity: UIDValidity?

        func parseSearchCorrelator_tag(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
            // tag-string = string
            try buffer.matchFixed("TAG ")
            tag = try decodeUTF8(self.parseString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchCorrelator_mailbox(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
            try buffer.matchFixed("MAILBOX ")
            mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_uidValidity(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
            try buffer.matchFixed("UIDVALIDITY ")
            uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_once(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) {
            try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseSearchCorrelator_tag(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseSearchCorrelator_mailbox(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseSearchCorrelator_uidValidity(buffer: &b, tracker: t) },
                tracker: tracker
            )
        }

        return try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")

            try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
            var result: SearchCorrelator
            if try buffer.parseOptional(
                tracker: tracker,
                parser: { input, _ throws(ParseFailure) in try input.parseSpaces() }
            ) != nil {
                // If we have 2, we must have the third.
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                guard let tag = tag, mailbox != nil, uidValidity != nil else {
                    throw .mismatch("Not all components present for SearchCorrelator")
                }
                result = SearchCorrelator(tag: tag, mailbox: mailbox, uidValidity: uidValidity)
            } else {
                guard let tag = tag else {
                    throw .mismatch("tag missing for SearchCorrelator")
                }
                result = SearchCorrelator(tag: tag)
            }

            try buffer.matchFixed(")")
            return result
        }
    }

    // search-critera = search-key *(search-key)
    func parseSearchCriteria(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [SearchKey] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
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
    func parseSearchKey(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
        func parseSearchKey_fixed(
            string: String,
            result: SearchKey,
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed(string)
            return result
        }

        func parseSearchKey_fixedOptions(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
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
                } catch .mismatch {
                    buffer = save
                }
            }
            throw .mismatch()
        }

        func parseSearchKey_bcc(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("BCC ")
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("BEFORE ")
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("BODY ")
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("CC ")
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("FROM ")
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("KEYWORD ")
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("ON ")
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SINCE ")
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SUBJECT ")
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("TEXT ")
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("TO ")
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("UNKEYWORD ")
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("FILTER ")
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("HEADER ")
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("LARGER ")
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SMALLER ")
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("NOT ")
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("OR ")
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SENTBEFORE ")
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SENTON ")
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("SENTSINCE ")
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("UID ")
            return .uid(
                try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty)
            )
        }

        func parseSearchKey_uidAfter(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("UIDAFTER ")
            return .uidAfter(
                try self.parseLastCommandMessageID(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: self.parseMessageIdentifier
                )
            )
        }

        func parseSearchKey_uidBefore(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("UIDBEFORE ")
            return .uidBefore(
                try self.parseLastCommandMessageID(
                    buffer: &buffer,
                    tracker: tracker,
                    setParser: self.parseMessageIdentifier
                )
            )
        }

        func parseSearchKey_sequenceSet(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            .sequenceNumbers(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("(")
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> SearchKey in
                try buffer.parseSpaces()
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")

            guard array.count == 1 else {
                return .and(array)
            }
            return array.first!
        }

        func parseSearchKey_older(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("OLDER ")
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("YOUNGER ")
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_modificationSequence(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            .modificationSequence(try self.parseSearchModificationSequence(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_emailID(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("EMAILID ")
            let objectID = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .emailID(EmailID(objectID))
        }

        func parseSearchKey_threadID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("THREADID ")
            let objectID = try self.parseObjectID(buffer: &buffer, tracker: tracker)
            return .threadID(ThreadID(objectID))
        }

        func parseSearchKey_gmailMessageID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("X-GM-MSGID ")
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseSearchKey_gmailThreadID(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("X-GM-THRID ")
            let (id, _) = try buffer.parseUnsignedInt64(tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseSearchKey_gmailRaw(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchKey {
            try buffer.matchFixed("X-GM-RAW ")
            return .gmailRaw(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        // Built in its own frame: the 35 closure values would otherwise sit in every recursion level's
        // frame (debug builds keep each `let`), and `(` nests this production up to the tracker limit.
        func alternatives() -> [ParseAlternative<SearchKey>] {
            let older = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_older(buffer: &b, tracker: t)
            }
            let fixedOptions = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_fixedOptions(buffer: &b, tracker: t)
            }
            let younger = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_younger(buffer: &b, tracker: t)
            }
            let bcc = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_bcc(buffer: &b, tracker: t)
            }
            let before = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_before(buffer: &b, tracker: t)
            }
            let body = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_body(buffer: &b, tracker: t)
            }
            let cc = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_cc(buffer: &b, tracker: t)
            }
            let from = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_from(buffer: &b, tracker: t)
            }
            let keyword = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_keyword(buffer: &b, tracker: t)
            }
            let on = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_on(buffer: &b, tracker: t)
            }
            let since = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_since(buffer: &b, tracker: t)
            }
            let subject = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_subject(buffer: &b, tracker: t)
            }
            let text = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_text(buffer: &b, tracker: t)
            }
            let to = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_to(buffer: &b, tracker: t)
            }
            let unkeyword = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_unkeyword(buffer: &b, tracker: t)
            }
            let header = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_header(buffer: &b, tracker: t)
            }
            let larger = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_larger(buffer: &b, tracker: t)
            }
            let smaller = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_smaller(buffer: &b, tracker: t)
            }
            let not = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_not(buffer: &b, tracker: t)
            }
            let or = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_or(buffer: &b, tracker: t)
            }
            let sentBefore = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_sentBefore(buffer: &b, tracker: t)
            }
            let sentOn = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_sentOn(buffer: &b, tracker: t)
            }
            let sentSince = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_sentSince(buffer: &b, tracker: t)
            }
            let uid = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_uid(buffer: &b, tracker: t)
            }
            let uidAfter = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_uidAfter(buffer: &b, tracker: t)
            }
            let uidBefore = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_uidBefore(buffer: &b, tracker: t)
            }
            let sequenceSet = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_sequenceSet(buffer: &b, tracker: t)
            }
            let array = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_array(buffer: &b, tracker: t)
            }
            let filter = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_filter(buffer: &b, tracker: t)
            }
            let modificationSequence = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_modificationSequence(buffer: &b, tracker: t)
            }
            let emailID = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_emailID(buffer: &b, tracker: t)
            }
            let threadID = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_threadID(buffer: &b, tracker: t)
            }
            let gmailMessageID = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_gmailMessageID(buffer: &b, tracker: t)
            }
            let gmailThreadID = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_gmailThreadID(buffer: &b, tracker: t)
            }
            let gmailRaw = ParseAlternative<SearchKey> { b, t throws(ParseFailure) in
                try parseSearchKey_gmailRaw(buffer: &b, tracker: t)
            }
            return [
                older,
                fixedOptions,
                younger,
                bcc,
                before,
                body,
                cc,
                from,
                keyword,
                on,
                since,
                subject,
                text,
                to,
                unkeyword,
                header,
                larger,
                smaller,
                not,
                or,
                sentBefore,
                sentOn,
                sentSince,
                uid,
                uidAfter,
                uidBefore,
                sequenceSet,
                array,
                filter,
                modificationSequence,
                emailID,
                threadID,
                gmailMessageID,
                gmailThreadID,
                gmailRaw,
            ]
        }
        return try buffer.parseOneOf(alternatives(), tracker: tracker)
    }

    func parseSearchModificationSequence(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SearchModificationSequence {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> SearchModificationSequence in
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
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<EntryFlagName, EntryKindRequest> {
        try buffer.composite(tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> KeyValue<EntryFlagName, EntryKindRequest> in
            try buffer.parseSpaces()
            let flag = try self.parseEntryFlagName(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let request = try self.parseEntryKindRequest(buffer: &buffer, tracker: tracker)
            return .init(key: flag, value: request)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    func parseSearchReturnDataExtension(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<ExtensionKey<SearchReturnData>, ParameterValue> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker throws(ParseFailure) -> KeyValue<ExtensionKey<SearchReturnData>, ParameterValue> in
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
    func parseSearchReturnData(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SearchReturnData {
        func parseSearchReturnData_min(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            try buffer.matchFixed("MIN ")
            return .min(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            try buffer.matchFixed("MAX ")
            return .max(try self.parseMessageIdentifier(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            try buffer.matchFixed("ALL ")
            return .all(try self.parseMessageIdentifierSetOrLast(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            try buffer.matchFixed("COUNT ")
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_modificationSequence(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            try buffer.matchFixed("MODSEQ ")
            return .modificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_partial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            func parseSearchReturnData_partial_set(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageIdentifierSet<UnknownMessageIdentifier> {
                try self.parseMessageIdentifierSet(buffer: &buffer, tracker: tracker).set
            }

            func parseSearchReturnData_partial_nil(
                buffer: inout ParseInput,
                tracker: StackTracker
            ) throws(ParseFailure) -> MessageIdentifierSet<UnknownMessageIdentifier> {
                try self.parseNil(buffer: &buffer, tracker: tracker)
                return []
            }

            try buffer.matchFixed("PARTIAL (")
            let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let set = ParseAlternative<MessageIdentifierSet<UnknownMessageIdentifier>> { b, t throws(ParseFailure) in
                try parseSearchReturnData_partial_set(buffer: &b, tracker: t)
            }
            let _nil = ParseAlternative<MessageIdentifierSet<UnknownMessageIdentifier>> { b, t throws(ParseFailure) in
                try parseSearchReturnData_partial_nil(buffer: &b, tracker: t)
            }
            let identifiers = try buffer.parseOneOf([set, _nil], tracker: tracker)
            try buffer.matchFixed(")")
            return .partial(range, identifiers)
        }

        func parseSearchReturnData_dataExtension(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        let min = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_min(buffer: &b, tracker: t)
        }
        let max = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_max(buffer: &b, tracker: t)
        }
        let all = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_all(buffer: &b, tracker: t)
        }
        let count = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_count(buffer: &b, tracker: t)
        }
        let modificationSequence = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_modificationSequence(buffer: &b, tracker: t)
        }
        let partial = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_partial(buffer: &b, tracker: t)
        }
        let dataExtension = ParseAlternative<SearchReturnData> { b, t throws(ParseFailure) in
            try parseSearchReturnData_dataExtension(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf(
            [
                min,
                max,
                all,
                count,
                modificationSequence,
                partial,
                dataExtension,
            ],
            tracker: tracker
        )
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    func parseSearchReturnOptions(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [SearchReturnOption] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.matchFixed(" RETURN (")
            let array =
                try buffer.parseOptional(tracker: tracker) {
                    (buffer, tracker) throws(ParseFailure) -> [SearchReturnOption] in
                    var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                    try buffer.parseZeroOrMore(into: &array, tracker: tracker) {
                        (buffer, tracker) throws(ParseFailure) -> SearchReturnOption in
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
    func parseSearchReturnOption(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SearchReturnOption {
        func parseSearchReturnOption_min(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("MIN")
            return .min
        }

        func parseSearchReturnOption_max(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("MAX")
            return .max
        }

        func parseSearchReturnOption_all(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("ALL")
            return .all
        }

        func parseSearchReturnOption_count(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("COUNT")
            return .count
        }

        func parseSearchReturnOption_save(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("SAVE")
            return .save
        }

        func parseSearchReturnOption_partial(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            try buffer.matchFixed("PARTIAL")
            try buffer.parseSpaces()
            let range = try parsePartialRange(buffer: &buffer, tracker: tracker)
            return .partial(range)
        }

        func parseSearchReturnOption_extension(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        let min = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_min(buffer: &b, tracker: t)
        }
        let max = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_max(buffer: &b, tracker: t)
        }
        let all = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_all(buffer: &b, tracker: t)
        }
        let count = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_count(buffer: &b, tracker: t)
        }
        let save = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_save(buffer: &b, tracker: t)
        }
        let partial = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_partial(buffer: &b, tracker: t)
        }
        let _extension = ParseAlternative<SearchReturnOption> { b, t throws(ParseFailure) in
            try parseSearchReturnOption_extension(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([min, max, all, count, save, partial, _extension], tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    func parseSearchReturnOptionExtension(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> KeyValue<ExtensionKey<SearchReturnOption>, ParameterValue?> {
        try buffer.composite(tracker: tracker) {
            buffer,
            tracker throws(ParseFailure) -> KeyValue<ExtensionKey<SearchReturnOption>, ParameterValue?> in
            let name: ExtensionKey<SearchReturnOption> = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ParameterValue in
                try buffer.parseSpaces()
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: params)
        }
    }

    func parseSearchSortModificationSequence(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> ModificationSequenceValue {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> ModificationSequenceValue in
            try buffer.matchFixed("(MODSEQ ")
            let modSeq = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(")")
            return modSeq
        }
    }
}
