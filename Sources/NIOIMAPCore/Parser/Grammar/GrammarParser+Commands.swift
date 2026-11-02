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

import OrderedCollections

// MARK: Top-level parser

extension GrammarParser {
    func parseTaggedCommand(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> TaggedCommand {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            // `do` inside a closure doesn't infer typed throws; annotate it.
            do throws(ParseFailure) {
                try buffer.parseSpaces()
                let command = try self.parseCommand(buffer: &buffer, tracker: tracker)
                return TaggedCommand(tag: tag, command: command)
            } catch .mismatch(let error) {
                throw .badCommand(BadCommand(commandTag: tag, parserError: error))
            }
        }
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    func parseCommand(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        return try self.selectingKeyword(buffer: &buffer) { keyword, buffer throws(ParseFailure) in
            switch keyword {
            case "CAPABILITY": return .capability
            case "LOGOUT": return .logout
            case "NOOP": return .noop
            case "STARTTLS": return .startTLS
            case "CHECK": return .check
            case "CLOSE": return .close
            case "EXPUNGE": return .expunge
            case "UNSELECT": return .unselect
            case "IDLE": return .idleStart
            case "NAMESPACE": return .namespace
            case "ID": return try self.parseCommandSuffix_id(buffer: &buffer, tracker: tracker)
            case "ENABLE": return try self.parseCommandSuffix_enable(buffer: &buffer, tracker: tracker)
            case "GETMETADATA": return try self.parseCommandSuffix_getMetadata(buffer: &buffer, tracker: tracker)
            case "SETMETADATA": return try self.parseCommandSuffix_setMetadata(buffer: &buffer, tracker: tracker)
            case "RESETKEY": return try self.parseCommandSuffix_resetKey(buffer: &buffer, tracker: tracker)
            case "GENURLAUTH": return try self.parseCommandSuffix_genURLAuth(buffer: &buffer, tracker: tracker)
            case "URLFETCH": return try self.parseCommandSuffix_urlFetch(buffer: &buffer, tracker: tracker)
            case "COPY": return try self.parseCommandSuffix_copy(buffer: &buffer, tracker: tracker)
            case "DELETE": return try self.parseCommandSuffix_delete(buffer: &buffer, tracker: tracker)
            case "MOVE": return try self.parseCommandSuffix_move(buffer: &buffer, tracker: tracker)
            case "SEARCH": return try self.parseCommandSuffix_search(buffer: &buffer, tracker: tracker)
            case "SORT": return try self.parseCommandSuffix_sort(buffer: &buffer, tracker: tracker)
            case "ESEARCH": return try self.parseCommandSuffix_esearch(buffer: &buffer, tracker: tracker)
            case "STORE": return try self.parseCommandSuffix_store(buffer: &buffer, tracker: tracker)
            case "EXAMINE": return try self.parseCommandSuffix_examine(buffer: &buffer, tracker: tracker)
            case "LIST": return try self.parseCommandSuffix_list(buffer: &buffer, tracker: tracker)
            case "LSUB": return try self.parseCommandSuffix_LSUB(buffer: &buffer, tracker: tracker)
            case "RENAME": return try self.parseCommandSuffix_rename(buffer: &buffer, tracker: tracker)
            case "SELECT": return try self.parseCommandSuffix_select(buffer: &buffer, tracker: tracker)
            case "STATUS": return try self.parseCommandSuffix_status(buffer: &buffer, tracker: tracker)
            case "SUBSCRIBE": return try self.parseCommandSuffix_subscribe(buffer: &buffer, tracker: tracker)
            case "UNSUBSCRIBE": return try self.parseCommandSuffix_unsubscribe(buffer: &buffer, tracker: tracker)
            case "UID": return try self.parseCommandSuffix_uid(buffer: &buffer, tracker: tracker)
            case "FETCH": return try self.parseCommandSuffix_fetch(buffer: &buffer, tracker: tracker)
            case "LOGIN": return try self.parseCommandSuffix_login(buffer: &buffer, tracker: tracker)
            case "AUTHENTICATE": return try self.parseCommandSuffix_authenticate(buffer: &buffer, tracker: tracker)
            case "CREATE": return try self.parseCommandSuffix_create(buffer: &buffer, tracker: tracker)
            case "GETQUOTA": return try self.parseCommandSuffix_getQuota(buffer: &buffer, tracker: tracker)
            case "SETQUOTA": return try self.parseCommandSuffix_setQuota(buffer: &buffer, tracker: tracker)
            case "GETQUOTAROOT": return try self.parseCommandSuffix_getQuotaRoot(buffer: &buffer, tracker: tracker)
            case "COMPRESS": return try self.parseCommandSuffix_compress(buffer: &buffer, tracker: tracker)
            case "UIDBATCHES": return try self.parseCommandSuffix_uidBatched(buffer: &buffer, tracker: tracker)
            case "GETJMAPACCESS": return .getJMAPAccess
            default: throw .mismatch("Not a command keyword")
            }
        }
    }
}

// MARK: - Command parsers

extension GrammarParser {
    struct SortCommandSuffix {
        var criteria: [SortCriterion]
        var charset: CharacterSetName
        var key: SearchKey
        var returnOptions: [SearchReturnOption]
    }

    func parseCommandSuffix_urlFetch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        let array = try buffer.parseOneOrMore(
            tracker: tracker,
            parser: { buffer, tracker throws(ParseFailure) -> [UInt8] in
                try buffer.parseSpaces()
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            }
        )
        return .urlFetch(array)
    }

    func parseCommandSuffix_getQuota(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            return .getQuota(quotaRoot)
        }
    }

    func parseCommandSuffix_setQuota(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let quotaLimits = try parseQuotaLimits(buffer: &buffer, tracker: tracker)
            return .setQuota(quotaRoot, quotaLimits)
        }
    }

    func parseCommandSuffix_getQuotaRoot(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            return .getQuotaRoot(mailbox)
        }
    }

    // authenticate  = "AUTHENTICATE" SP auth-type [SP (base64 / "=")] *(CRLF base64)
    func parseCommandSuffix_authenticate(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mechanism = try self.parseAuthenticationMechanism(buffer: &buffer, tracker: tracker)
            let initialResponse = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> InitialResponse in
                    try buffer.parseSpaces()
                    return try self.parseInitialResponse(buffer: &buffer, tracker: tracker)
                }
            )
            return .authenticate(mechanism: mechanism, initialResponse: initialResponse)
        }
    }

    // login           = "LOGIN" SP userid SP password
    func parseCommandSuffix_login(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let userid = try self.parseUserId(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" ")
            let password = try self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    func parseCommandSuffix_unsubscribe(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    func parseCommandSuffix_subscribe(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    func parseCommandSuffix_status(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" (")
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &atts, tracker: tracker) {
                buffer,
                tracker throws(ParseFailure) -> MailboxAttribute in
                try buffer.matchFixed(" ")
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return .status(mailbox, atts)
        }
    }

    // select          = "SELECT" SP mailbox [select-params]
    func parseCommandSuffix_select(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try self.parseSelectParameters(buffer: &buffer, tracker: tracker)
            return .select(mailbox, params)
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    func parseCommandSuffix_rename(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" ", caseSensitivity: .caseInsensitive)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params: OrderedDictionary<ExtensionKey<Command>, ParameterValue?> =
                try buffer.parseOptional(tracker: tracker, parser: self.parseParameters) ?? [:]
            return .rename(from: from, to: to, parameters: params)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    func parseCommandSuffix_LSUB(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    func parseCommandSuffix_examine(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try self.parseSelectParameters(buffer: &buffer, tracker: tracker)
            return .examine(mailbox, params)
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    func parseCommandSuffix_store(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let sequence: LastCommandSet<SequenceNumber> = try self.parseMessageIdentifierSetOrLast(
                buffer: &buffer,
                tracker: tracker
            )
            let modifiers =
                try buffer.parseOptional(tracker: tracker, parser: self.parseStoreModifiers) ?? []
            try buffer.parseSpaces()
            let storeData = try self.parseStoreData(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, storeData)
        }
    }

    // RFC 7377
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    func parseCommandSuffix_esearch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        .extendedSearch(try parseExtendedSearchOptions(buffer: &buffer, tracker: tracker))
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    func parseCommandSuffix_move(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let set: LastCommandSet<SequenceNumber> = try self.parseMessageIdentifierSetOrLast(
                buffer: &buffer,
                tracker: tracker
            )
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    // delete          = "DELETE" SP mailbox
    func parseCommandSuffix_delete(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    func parseCommandSuffix_copy(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let sequence: LastCommandSet<SequenceNumber> = try self.parseMessageIdentifierSetOrLast(
                buffer: &buffer,
                tracker: tracker
            )
            try buffer.matchFixed(" ")
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    func parseCommandSuffix_create(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params =
                try buffer.parseOptional(tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    func parseCommandSuffix_enable(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        let capabilities = try buffer.parseOneOrMore(tracker: tracker) {
            (buffer, tracker) throws(ParseFailure) -> Capability in
            try buffer.parseSpaces()
            return try self.parseCapability(buffer: &buffer, tracker: tracker)
        }
        return .enable(capabilities)
    }

    // id = "ID" SP id-params-list
    func parseCommandSuffix_id(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.parseSpaces()
            return .id(try parseIDParamsList(buffer: &buffer, tracker: tracker))
        }
    }

    func parseCommandSuffix_getMetadata(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            let options =
                try buffer.parseOptional(
                    tracker: tracker,
                    parser: { buffer, tracker throws(ParseFailure) -> [MetadataOption] in
                        let options = try self.parseMetadataOptions(buffer: &buffer, tracker: tracker)
                        try buffer.parseSpaces()
                        return options
                    }
                ) ?? []
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let entries = try self.parseEntries(buffer: &buffer, tracker: tracker)
            return .getMetadata(options: options, mailbox: mailbox, entries: entries)
        }
    }

    func parseCommandSuffix_setMetadata(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let list = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .setMetadata(mailbox: mailbox, entries: list)
        }
    }

    func parseCommandSuffix_resetKey(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let _mailbox = try buffer.parseOptional(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> MailboxName in
                    try buffer.parseSpaces()
                    return try self.parseMailbox(buffer: &buffer, tracker: tracker)
                }
            )

            // don't bother parsing mechanisms if there's no mailbox
            guard let mailbox = _mailbox else {
                return .resetKey(.allMailboxes)
            }

            let mechanisms = try buffer.parseZeroOrMore(
                tracker: tracker,
                parser: { buffer, tracker throws(ParseFailure) -> URLAuthenticationMechanism in
                    try buffer.parseSpaces()
                    return try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
                }
            )
            return .resetKey(.mailbox(mailbox, mechanisms: mechanisms))
        }
    }

    func parseCommandSuffix_genURLAuth(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        let array = try buffer.parseOneOrMore(
            tracker: tracker,
            parser: { buffer, tracker throws(ParseFailure) -> RumpURLAndMechanism in
                try buffer.parseSpaces()
                return try self.parseURLRumpMechanism(buffer: &buffer, tracker: tracker)
            }
        )
        return .generateAuthorizedURL(array)
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    func parseCommandSuffix_search(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let returnOpts = try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseSearchReturnOptions
            )
            try buffer.parseSpaces()
            let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
            guard let o = returnOpts else {
                // No options -> normal search with `returnOptions: []`
                return .search(key: program, charset: charset, returnOptions: [])
            }
            // We have options. Map an empty options list to `[.all]`:
            return .search(key: program, charset: charset, returnOptions: (o == []) ? [.all] : o)
        }
    }

    // sort            = "SORT" [search-return-opts] SP sort-criteria SP charset SP search-key
    func parseCommandSuffix_sort(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        let suffix = try self.parseCommandSuffix_sortShared(buffer: &buffer, tracker: tracker)
        return .sort(
            criteria: suffix.criteria,
            charset: suffix.charset,
            key: suffix.key,
            returnOptions: suffix.returnOptions
        )
    }

    func parseCommandSuffix_sortShared(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SortCommandSuffix {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let returnOpts = try buffer.parseOptional(
                tracker: tracker,
                parser: self.parseSearchReturnOptions
            )
            try buffer.parseSpaces()
            let criteria = try self.parseSortCriteria(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            var keys = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &keys, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> SearchKey in
                try buffer.parseSpaces()
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            let key: SearchKey
            if keys.count == 1 {
                key = keys.first!
            } else {
                key = .and(keys)
            }
            guard let o = returnOpts else {
                return SortCommandSuffix(criteria: criteria, charset: charset, key: key, returnOptions: [])
            }
            return SortCommandSuffix(
                criteria: criteria,
                charset: charset,
                key: key,
                returnOptions: (o == []) ? [.all] : o
            )
        }
    }

    // sort-criteria   = "(" sort-key *(SP sort-key) ")"
    func parseSortCriteria(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> [SortCriterion] {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            try buffer.matchFixed("(")
            var criteria = [try self.parseSortCriterion(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(into: &criteria, tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> SortCriterion in
                try buffer.parseSpaces()
                return try self.parseSortCriterion(buffer: &buffer, tracker: tracker)
            }
            try buffer.matchFixed(")")
            return criteria
        }
    }

    // sort-key        = "ARRIVAL" / "CC" / "DATE" / "FROM" /
    //                   "REVERSE" SP sort-key-no-reverse / "SIZE" / "SUBJECT" / "TO" /
    //                   "DISPLAYFROM" / "DISPLAYTO"
    func parseSortCriterion(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> SortCriterion {
        func parseSortCriterion_reverse(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion {
            try buffer.matchFixed("REVERSE ")
            return .descending(try self.parseSortCriterionKey(buffer: &buffer, tracker: tracker))
        }

        func parseSortCriterion_ascending(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion {
            .ascending(try self.parseSortCriterionKey(buffer: &buffer, tracker: tracker))
        }

        let reverse = ParseAlternative<SortCriterion> { b, t throws(ParseFailure) in
            try parseSortCriterion_reverse(buffer: &b, tracker: t)
        }
        let ascending = ParseAlternative<SortCriterion> { b, t throws(ParseFailure) in
            try parseSortCriterion_ascending(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf([reverse, ascending], tracker: tracker)
    }

    func parseSortCriterionKey(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> SortCriterion.Key {
        func parseSortCriterion_displayFrom(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("DISPLAYFROM")
            return .displayFrom
        }

        func parseSortCriterion_displayTo(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("DISPLAYTO")
            return .displayTo
        }

        func parseSortCriterion_arrival(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("ARRIVAL")
            return .arrival
        }

        func parseSortCriterion_cc(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("CC")
            return .cc
        }

        func parseSortCriterion_date(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("DATE")
            return .date
        }

        func parseSortCriterion_from(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("FROM")
            return .from
        }

        func parseSortCriterion_size(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("SIZE")
            return .size
        }

        func parseSortCriterion_subject(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("SUBJECT")
            return .subject
        }

        func parseSortCriterion_to(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> SortCriterion.Key {
            try buffer.matchFixed("TO")
            return .to
        }

        let displayFrom = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_displayFrom(buffer: &b, tracker: t)
        }
        let displayTo = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_displayTo(buffer: &b, tracker: t)
        }
        let arrival = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_arrival(buffer: &b, tracker: t)
        }
        let cc = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_cc(buffer: &b, tracker: t)
        }
        let date = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_date(buffer: &b, tracker: t)
        }
        let from = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_from(buffer: &b, tracker: t)
        }
        let size = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_size(buffer: &b, tracker: t)
        }
        let subject = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_subject(buffer: &b, tracker: t)
        }
        let to = ParseAlternative<SortCriterion.Key> { b, t throws(ParseFailure) in
            try parseSortCriterion_to(buffer: &b, tracker: t)
        }
        return try buffer.parseOneOf(
            [
                displayFrom,
                displayTo,
                arrival,
                cc,
                date,
                from,
                size,
                subject,
                to,
            ],
            tracker: tracker
        )
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    func parseCommandSuffix_list(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { (buffer, tracker) throws(ParseFailure) in
            let selectOptions = try buffer.parseOptional(tracker: tracker) {
                (buffer, tracker) throws(ParseFailure) -> ListSelectOptions in
                try buffer.parseSpaces()
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try buffer.parseSpaces()
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try buffer.parseSpaces()
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions =
                try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> [ReturnOption] in
                    try buffer.parseSpaces()
                    return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
                } ?? []
            return .list(selectOptions, reference: mailbox, mailboxPatterns, returnOptions)
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    func parseCommandSuffix_uid(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        func parseUid_copy(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
                try buffer.matchFixed("COPY ")
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed(" ")
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidCopy(.set(set), mailbox)
            }
        }

        func parseUid_move(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
                try buffer.matchFixed("MOVE ")
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidMove(.set(set), mailbox)
            }
        }

        func parseUid_fetch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
                try buffer.matchFixed("FETCH ")
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try buffer.parseSpaces()
                let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
                let modifiers =
                    try buffer.parseOptional(tracker: tracker, parser: self.parseFetchModifiers) ?? []
                return .uidFetch(.set(set), att, modifiers)
            }
        }

        func parseUid_search(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed("SEARCH")
                guard
                    case .search(let key, let charset, let returnOptions) = try self.parseCommandSuffix_search(
                        buffer: &buffer,
                        tracker: tracker
                    )
                else {
                    fatalError("This should never happen")
                }
                return .uidSearch(key: key, charset: charset, returnOptions: returnOptions)
            }
        }

        func parseUid_sort(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed("SORT")
                let suffix = try self.parseCommandSuffix_sortShared(buffer: &buffer, tracker: tracker)
                return .uidSort(
                    criteria: suffix.criteria,
                    charset: suffix.charset,
                    key: suffix.key,
                    returnOptions: suffix.returnOptions
                )
            }
        }

        func parseUid_store(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
                try buffer.matchFixed("STORE ")
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                let modifiers =
                    try buffer.parseOptional(tracker: tracker, parser: self.parseStoreModifiers) ?? []
                try buffer.parseSpaces()
                let storeData = try self.parseStoreData(buffer: &buffer, tracker: tracker)
                return .uidStore(.set(set), modifiers, storeData)
            }
        }

        func parseUid_expunge(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
            try buffer.matchFixed("EXPUNGE ")
            let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
            return .uidExpunge(.set(set))
        }

        return try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let copy = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_copy(buffer: &b, tracker: t)
            }
            let move = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_move(buffer: &b, tracker: t)
            }
            let fetch = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_fetch(buffer: &b, tracker: t)
            }
            let search = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_search(buffer: &b, tracker: t)
            }
            let sort = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_sort(buffer: &b, tracker: t)
            }
            let store = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_store(buffer: &b, tracker: t)
            }
            let expunge = ParseAlternative<Command> { b, t throws(ParseFailure) in
                try parseUid_expunge(buffer: &b, tracker: t)
            }
            return try buffer.parseOneOf([copy, move, fetch, search, sort, store, expunge], tracker: tracker)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    func parseCommandSuffix_fetch(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let sequence: LastCommandSet<SequenceNumber> = try self.parseMessageIdentifierSetOrLast(
                buffer: &buffer,
                tracker: tracker
            )
            try buffer.parseSpaces()
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers =
                try buffer.parseOptional(tracker: tracker, parser: self.parseFetchModifiers) ?? []
            return .fetch(sequence, att, modifiers)
        }
    }

    func parseCommandSuffix_compress(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let rawAlg = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let alg = Capability.CompressionKind(unchecked: rawAlg)
            return .compress(alg)
        }
    }

    // message-batches     = "UIDBATCHES" SP nz-number
    //                       [SP nz-number ":" nz-number]
    func parseCommandSuffix_uidBatched(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> Command {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) -> Command in
            try buffer.parseSpaces()
            let size = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            let range: MessageIdentifierRange<UnknownMessageIdentifier>? = try buffer.parseOptional(
                tracker: tracker
            ) { buffer, tracker throws(ParseFailure) in
                try buffer.parseSpaces()
                return try self.parseMessageIdentifierRange(buffer: &buffer, tracker: tracker)
            }
            let batchRange = range.map {
                Int($0.lowerBound)...Int($0.upperBound)
            }
            return .uidBatches(batchSize: Int(size), batchRange: batchRange)
        }
    }

    func parseSelectParameters(
        buffer: inout ParseInput,
        tracker: StackTracker
    ) throws(ParseFailure) -> [SelectParameter] {
        try buffer.parseOptional(tracker: tracker) { (buffer, tracker) throws(ParseFailure) -> [SelectParameter] in
            try buffer.parseSpaces()
            try buffer.matchFixed("(")
            var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
            try buffer.parseZeroOrMore(
                into: &array,
                tracker: tracker,
                parser: { (buffer, tracker) throws(ParseFailure) in
                    try buffer.parseSpaces()
                    return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
                }
            )
            try buffer.matchFixed(")")
            return array
        } ?? []
    }
}
