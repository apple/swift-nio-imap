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
    // search-program     = ["CHARSET" SP charset SP]
    //                         search-key *(SP search-key)
    //                         ;; CHARSET argument to SEARCH MUST be
    //                         ;; registered with IANA.
    static func parseSearchProgram(buffer: inout ParseBuffer, tracker: StackTracker) throws -> (String?, SearchKey) {
        let charset = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
            try self.fixedString("CHARSET ", buffer: &buffer, tracker: tracker)
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            return charset
        }
        var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
        try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
            try self.spaces(buffer: &buffer, tracker: tracker)
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

    // RFC 6237
    // one-correlator =  ("TAG" SP tag-string) / ("MAILBOX" SP astring) /
    //                      ("UIDVALIDITY" SP nz-number)
    //                      ; Each correlator MUST appear exactly once.
    // search-correlator =  SP "(" one-correlator *(SP one-correlator) ")"
    static func parseSearchCorrelator(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchCorrelator {
        var tag: ByteBuffer?
        var mailbox: MailboxName?
        var uidValidity: UIDValidity?

        func parseSearchCorrelator_tag(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try self.fixedString("TAG ", buffer: &buffer, tracker: tracker)
            tag = try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_mailbox(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try self.fixedString("MAILBOX ", buffer: &buffer, tracker: tracker)
            mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_uidValidity(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try self.fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_once(buffer: inout ParseBuffer, tracker: StackTracker) throws {
            try self.oneOf(
                parseSearchCorrelator_tag,
                parseSearchCorrelator_mailbox,
                parseSearchCorrelator_uidValidity,
                buffer: &buffer,
                tracker: tracker
            )
        }

        return try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString(" (", buffer: &buffer, tracker: tracker)

            try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
            var result: SearchCorrelator
            if try self.optional(buffer: &buffer, tracker: tracker, parser: self.spaces) != nil {
                // If we have 2, we must have the third.
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                try self.spaces(buffer: &buffer, tracker: tracker)
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                if let tag = tag, mailbox != nil, uidValidity != nil {
                    result = SearchCorrelator(tag: tag, mailbox: mailbox, uidValidity: uidValidity)
                } else {
                    throw ParserError(hint: "Not all components present for SearchCorrelator")
                }
            } else {
                if let tag = tag {
                    result = SearchCorrelator(tag: tag)
                } else {
                    throw ParserError(hint: "tag missing for SearchCorrelator")
                }
            }

            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try self.spaces(buffer: &buffer, tracker: tracker)
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
    static func parseSearchKey(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
        func parseSearchKey_fixed(string: String, result: SearchKey, buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString(string, buffer: &buffer, tracker: tracker)
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
            try self.fixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty))
        }

        func parseSearchKey_sequenceSet(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceNumbers(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try self.fixedString(")", buffer: &buffer, tracker: tracker)

            if array.count == 1 {
                return array.first!
            } else {
                return .and(array)
            }
        }

        func parseSearchKey_older(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            try self.fixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_modificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchKey {
            .modificationSequence(try self.parseSearchModificationSequence(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseSearchKey_older,
            parseSearchKey_fixedOptions,
            parseSearchKey_younger,
            parseSearchKey_bcc,
            parseSearchKey_before,
            parseSearchKey_body,
            parseSearchKey_cc,
            parseSearchKey_from,
            parseSearchKey_keyword,
            parseSearchKey_on,
            parseSearchKey_since,
            parseSearchKey_subject,
            parseSearchKey_text,
            parseSearchKey_to,
            parseSearchKey_unkeyword,
            parseSearchKey_header,
            parseSearchKey_larger,
            parseSearchKey_smaller,
            parseSearchKey_not,
            parseSearchKey_or,
            parseSearchKey_sentBefore,
            parseSearchKey_sentOn,
            parseSearchKey_sentSince,
            parseSearchKey_uid,
            parseSearchKey_sequenceSet,
            parseSearchKey_array,
            parseSearchKey_filter,
            parseSearchKey_modificationSequence,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseSearchModificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchModificationSequence {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchModificationSequence in
            try self.fixedString("MODSEQ", buffer: &buffer, tracker: tracker)
            var extensions = KeyValues<EntryFlagName, EntryKindRequest>()
            try self.zeroOrMore(buffer: &buffer, into: &extensions, tracker: tracker, parser: self.parseSearchModificationSequenceExtension)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(extensions: extensions, sequenceValue: val)
        }
    }

    static func parseSearchModificationSequenceExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<EntryFlagName, EntryKindRequest> {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> KeyValue<EntryFlagName, EntryKindRequest> in
            try self.spaces(buffer: &buffer, tracker: tracker)
            let flag = try self.parseEntryFlagName(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let request = try self.parseEntryKindRequest(buffer: &buffer, tracker: tracker)
            return .init(key: flag, value: request)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue> {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, ParameterValue> in
            let modifier = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try self.spaces(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: modifier, value: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try self.fixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try self.fixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try self.fixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try self.fixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_modificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try self.fixedString("MODSEQ ", buffer: &buffer, tracker: tracker)
            return .modificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try self.oneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_modificationSequence,
            parseSearchReturnData_dataExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try self.fixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try self.zeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchReturnOption in
                    try self.spaces(buffer: &buffer, tracker: tracker)
                    return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      search-ret-opt-ext
    static func parseSearchReturnOption(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try self.fixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try self.fixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try self.fixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try self.fixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try self.fixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try self.oneOf([
            parseSearchReturnOption_min,
            parseSearchReturnOption_max,
            parseSearchReturnOption_all,
            parseSearchReturnOption_count,
            parseSearchReturnOption_save,
            parseSearchReturnOption_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    static func parseSearchReturnOptionExtension(buffer: inout ParseBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue?> {
        try self.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, ParameterValue?> in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try self.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try self.spaces(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: params)
        }
    }

    static func parseSearchSortModificationSequence(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ModificationSequenceValue {
        try self.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ModificationSequenceValue in
            try self.fixedString("(MODSEQ ", buffer: &buffer, tracker: tracker)
            let modSeq = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try self.fixedString(")", buffer: &buffer, tracker: tracker)
            return modSeq
        }
    }
}
