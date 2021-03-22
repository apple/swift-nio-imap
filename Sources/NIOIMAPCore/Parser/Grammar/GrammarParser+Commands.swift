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

// MARK: Top-level parser

extension GrammarParser {
    static func parseTaggedCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let command = try self.parseCommand(buffer: &buffer, tracker: tracker)
            return TaggedCommand(tag: tag, command: command)
        }
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        let commandParsers: [String: (inout ParseBuffer, StackTracker) throws -> Command] = [
            "CAPABILITY": { _, _ in .capability },
            "LOGOUT": { _, _ in .logout },
            "NOOP": { _, _ in .noop },
            "STARTTLS": { _, _ in .starttls },
            "CHECK": { _, _ in .check },
            "CLOSE": { _, _ in .close },
            "EXPUNGE": { _, _ in .expunge },
            "UNSELECT": { _, _ in .unselect },
            "IDLE": { _, _ in .idleStart },
            "NAMESPACE": { _, _ in .namespace },
            "ID": GrammarParser.parseCommandSuffix_id,
            "ENABLE": GrammarParser.parseCommandSuffix_enable,
            "GETMETADATA": GrammarParser.parseCommandSuffix_getMetadata,
            "SETMETADATA": GrammarParser.parseCommandSuffix_setMetadata,
            "RESETKEY": GrammarParser.parseCommandSuffix_resetKey,
            "GENURLAUTH": GrammarParser.parseCommandSuffix_genURLAuth,
            "URLFETCH": GrammarParser.parseCommandSuffix_urlFetch,
            "COPY": GrammarParser.parseCommandSuffix_copy,
            "DELETE": GrammarParser.parseCommandSuffix_delete,
            "MOVE": GrammarParser.parseCommandSuffix_move,
            "SEARCH": GrammarParser.parseCommandSuffix_search,
            "ESEARCH": GrammarParser.parseCommandSuffix_esearch,
            "STORE": GrammarParser.parseCommandSuffix_store,
            "EXAMINE": GrammarParser.parseCommandSuffix_examine,
            "LIST": GrammarParser.parseCommandSuffix_list,
            "LSUB": GrammarParser.parseCommandSuffix_LSUB,
            "RENAME": GrammarParser.parseCommandSuffix_rename,
            "SELECT": GrammarParser.parseCommandSuffix_select,
            "STATUS": GrammarParser.parseCommandSuffix_status,
            "SUBSCRIBE": GrammarParser.parseCommandSuffix_subscribe,
            "UNSUBSCRIBE": GrammarParser.parseCommandSuffix_unsubscribe,
            "UID": GrammarParser.parseCommandSuffix_uid,
            "FETCH": GrammarParser.parseCommandSuffix_fetch,
            "LOGIN": GrammarParser.parseCommandSuffix_login,
            "AUTHENTICATE": GrammarParser.parseCommandSuffix_authenticate,
            "CREATE": GrammarParser.parseCommandSuffix_create,
            "GETQUOTA": GrammarParser.parseCommandSuffix_getQuota,
            "SETQUOTA": GrammarParser.parseCommandSuffix_setQuota,
            "GETQUOTAROOT": GrammarParser.parseCommandSuffix_getQuotaRoot,
        ]
        return try parseFromLookupTable(buffer: &buffer, tracker: tracker, parsers: commandParsers)
    }
}

// MARK: - Command parsers

extension GrammarParser {
    static func parseCommandSuffix_urlFetch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            return try self.parseAString(buffer: &buffer, tracker: tracker)
        })
        return .urlFetch(array)
    }

    static func parseCommandSuffix_getQuota(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            return .getQuota(quotaRoot)
        }
    }

    static func parseCommandSuffix_setQuota(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let quotaLimits = try parseQuotaLimits(buffer: &buffer, tracker: tracker)
            return .setQuota(quotaRoot, quotaLimits)
        }
    }

    static func parseCommandSuffix_getQuotaRoot(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            return .getQuotaRoot(mailbox)
        }
    }

    // authenticate  = "AUTHENTICATE" SP auth-type [SP (base64 / "=")] *(CRLF base64)
    static func parseCommandSuffix_authenticate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let authMethod = AuthenticationKind(try self.parseAtom(buffer: &buffer, tracker: tracker))
            let parseInitialClientResponse = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> InitialClientResponse in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseInitialClientResponse(buffer: &buffer, tracker: tracker)
            })
            return .authenticate(method: authMethod, initialClientResponse: parseInitialClientResponse)
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseCommandSuffix_login(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseCommandSuffix_unsubscribe(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseCommandSuffix_subscribe(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseCommandSuffix_status(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseCommandSuffix_select(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SelectParameter] in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                try ParserLibrary.fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
                })
                try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            }
            return .select(mailbox, params ?? [])
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseCommandSuffix_rename(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
            return .rename(from: from, to: to, params: params)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseCommandSuffix_LSUB(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseCommandSuffix_examine(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
            return .examine(mailbox, params)
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseCommandSuffix_store(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> [StoreModifier] in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                try ParserLibrary.fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                })
                try ParserLibrary.fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    static func parseCommandSuffix_esearch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        .extendedsearch(try parseExtendedSearchOptions(buffer: &buffer, tracker: tracker))
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseCommandSuffix_move(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseCommandSuffix_delete(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCommandSuffix_copy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCommandSuffix_create(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseCommandSuffix_enable(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            return try self.parseCapability(buffer: &buffer, tracker: tracker)
        }
        return .enable(capabilities)
    }

    // id = "ID" SP id-params-list
    static func parseCommandSuffix_id(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            return .id(try parseIDParamsList(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseCommandSuffix_getMetadata(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let options = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> [MetadataOption] in
                let options = try self.parseMetadataOptions(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return options
            }) ?? []
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let entries = try self.parseEntries(buffer: &buffer, tracker: tracker)
            return .getMetadata(options: options, mailbox: mailbox, entries: entries)
        }
    }

    static func parseCommandSuffix_setMetadata(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .setMetadata(mailbox: mailbox, entries: list)
        }
    }

    static func parseCommandSuffix_resetKey(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let _mailbox = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> MailboxName in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseMailbox(buffer: &buffer, tracker: tracker)
            })

            // don't bother parsing mechanisms if there's no mailbox
            guard let mailbox = _mailbox else {
                return .resetKey(mailbox: nil, mechanisms: [])
            }

            let mechanisms = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> URLAuthenticationMechanism in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            })
            return .resetKey(mailbox: mailbox, mechanisms: mechanisms)
        }
    }

    static func parseCommandSuffix_genURLAuth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> RumpURLAndMechanism in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            return try self.parseURLRumpMechanism(buffer: &buffer, tracker: tracker)
        })
        return .generateAuthorizedURL(array)
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseCommandSuffix_search(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let returnOpts = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions) ?? []
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
            return .search(key: program, charset: charset, returnOptions: returnOpts)
        }
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseCommandSuffix_list(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let selectOptions = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOptions in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try ParserLibrary.optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, reference: mailbox, mailboxPatterns, returnOptions)
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseCommandSuffix_uid(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        func parseUid_copy(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("COPY ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidCopy(.set(set), mailbox)
            }
        }

        func parseUid_move(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("MOVE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidMove(.set(set), mailbox)
            }
        }

        func parseUid_fetch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("FETCH ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
                let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
                return .uidFetch(.set(set), att, modifiers)
            }
        }

        func parseUid_search(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try ParserLibrary.fixedString("SEARCH", buffer: &buffer, tracker: tracker)
                guard case .search(let key, let charset, let returnOptions) = try self.parseCommandSuffix_search(buffer: &buffer, tracker: tracker) else {
                    fatalError("This should never happen")
                }
                return .uidSearch(key: key, charset: charset, returnOptions: returnOptions)
            }
        }

        func parseUid_store(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try ParserLibrary.fixedString("STORE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
                let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
                try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
                let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
                return .uidStore(.set(set), modifiers, flags)
            }
        }

        func parseUid_expunge(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.fixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseUIDSetNonEmpty(buffer: &buffer, tracker: tracker)
            return .uidExpunge(.set(set))
        }

        return try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            return try ParserLibrary.oneOf([
                parseUid_copy,
                parseUid_move,
                parseUid_fetch,
                parseUid_search,
                parseUid_store,
                parseUid_expunge,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    static func parseCommandSuffix_fetch(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpaces(buffer: &buffer, tracker: tracker)
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
            return .fetch(sequence, att, modifiers)
        }
    }
}
