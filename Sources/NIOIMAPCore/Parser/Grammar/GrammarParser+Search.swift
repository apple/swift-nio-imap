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
    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let returnOpts = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions) ?? []
            try space(buffer: &buffer, tracker: tracker)
            let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
            return .search(key: program, charset: charset, returnOptions: returnOpts)
        }
    }

    // search-program     = ["CHARSET" SP charset SP]
    //                         search-key *(SP search-key)
    //                         ;; CHARSET argument to SEARCH MUST be
    //                         ;; registered with IANA.
    static func parseSearchProgram(buffer: inout ByteBuffer, tracker: StackTracker) throws -> (String?, SearchKey) {
        let charset = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
            try fixedString("CHARSET ", buffer: &buffer, tracker: tracker)
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            return charset
        }
        var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
            try space(buffer: &buffer, tracker: tracker)
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
    static func parseSearchCorrelator(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchCorrelator {
        var tag: ByteBuffer?
        var mailbox: MailboxName?
        var uidValidity: UIDValidity?

        func parseSearchCorrelator_tag(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("TAG ", buffer: &buffer, tracker: tracker)
            tag = try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_mailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("MAILBOX ", buffer: &buffer, tracker: tracker)
            mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            uidValidity = try self.parseUIDValidity(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_once(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try oneOf([
                parseSearchCorrelator_tag,
                parseSearchCorrelator_mailbox,
                parseSearchCorrelator_uidValidity,
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" (", buffer: &buffer, tracker: tracker)

            try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
            var result: SearchCorrelator
            if try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                // If we have 2, we must have the third.
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
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

            try fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
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
    static func parseSearchKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
        func parseSearchKey_fixed(string: String, result: SearchKey, buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString(string, buffer: &buffer, tracker: tracker)
            return result
        }

        func parseSearchKey_fixedOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
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

        func parseSearchKey_bcc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseLastCommandSet(buffer: &buffer, tracker: tracker, setParser: self.parseUIDSetNonEmpty))
        }

        func parseSearchKey_sequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceNumbers(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)

            if array.count == 1 {
                return array.first!
            } else {
                return .and(array)
            }
        }

        func parseSearchKey_older(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .modificationSequence(try self.parseSearchModificationSequence(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
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

    static func parseSearchModificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchModificationSequence {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchModificationSequence in
            try fixedString("MODSEQ", buffer: &buffer, tracker: tracker)
            var extensions = KeyValues<EntryFlagName, EntryKindRequest>()
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &extensions, tracker: tracker, parser: self.parseSearchModificationSequenceExtension)
            try space(buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(extensions: extensions, sequenceValue: val)
        }
    }

    static func parseSearchModificationSequenceExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<EntryFlagName, EntryKindRequest> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> KeyValue<EntryFlagName, EntryKindRequest> in
            try space(buffer: &buffer, tracker: tracker)
            let flag = try self.parseEntryFlagName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let request = try self.parseEntryKindRequest(buffer: &buffer, tracker: tracker)
            return .init(key: flag, value: request)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue> {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, ParameterValue> in
            let modifier = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(key: modifier, value: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MODSEQ ", buffer: &buffer, tracker: tracker)
            return .modificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_modificationSequence,
            parseSearchReturnData_dataExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchReturnOption in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      search-ret-opt-ext
    static func parseSearchReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try oneOf([
            parseSearchReturnOption_min,
            parseSearchReturnOption_max,
            parseSearchReturnOption_all,
            parseSearchReturnOption_count,
            parseSearchReturnOption_save,
            parseSearchReturnOption_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    static func parseSearchReturnOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> KeyValue<String, ParameterValue?> {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> KeyValue<String, ParameterValue?> in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(key: name, value: params)
        }
    }

    static func parseSearchSortModificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ModificationSequenceValue {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ModificationSequenceValue in
            try fixedString("(MODSEQ ", buffer: &buffer, tracker: tracker)
            let modSeq = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return modSeq
        }
    }
}
