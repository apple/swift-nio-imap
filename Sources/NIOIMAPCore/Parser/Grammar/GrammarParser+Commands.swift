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

// MARK: - Parsing map

fileprivate let commandParsers: [String: (inout ByteBuffer, StackTracker) throws -> Command] = [
    "CAPABILITY" : { _, _ in return .capability },
    "LOGOUT" : { _, _ in return .logout },
    "NOOP" : { _, _ in return .noop },
    "STARTTLS" : { _, _ in return .starttls },
    "CHECK" : { _, _ in return .check },
    "CLOSE" : { _, _ in return .close },
    "EXPUNGE" : { _, _ in return .expunge },
    "UNSELECT" : { _, _ in return .unselect },
    "IDLE": { _, _ in return .idleStart },
    "NAMESPACE": { _, _ in return .namespace },
    "ID" : GrammarParser.parseID,
    "ENABLE" : GrammarParser.parseEnable,
    "GETMETADATA" : GrammarParser.parseCommandAuth_getMetadata,
    "SETMETADATA" : GrammarParser.parseCommandAuth_setMetadata,
    "RESETKEY" : GrammarParser.parseCommandAuth_resetKey,
    "GENURLAUTH" : GrammarParser.parseCommandAuth_genURLAuth,
    "URLFETCH" : GrammarParser.parseCommandAuth_urlFetch,
    "COPY": GrammarParser.parseCopy,
    "DELETE": GrammarParser.parseDelete,
    "MOVE": GrammarParser.parseMove,
    "SEARCH": GrammarParser.parseSearch,
    "ESEARCH": GrammarParser.parseEsearch,
    "STORE": GrammarParser.parseStore,
    "EXAMINE": GrammarParser.parseExamine,
    "LIST": GrammarParser.parseList,
    "LSUB": GrammarParser.parseLSUB,
    "RENAME": GrammarParser.parseRename,
    "SELECT": GrammarParser.parseSelect,
    "STATUS": GrammarParser.parseStatus,
    "SUBSCRIBE": GrammarParser.parseSubscribe,
    "UNSUBSCRIBE": GrammarParser.parseUnsubscribe,
    "UID": GrammarParser.parseUid,
    "FETCH": GrammarParser.parseFetch,
    "LOGIN": GrammarParser.parseLogin,
    "AUTHENTICATE": GrammarParser.parseAuthenticate,
    "CREATE": GrammarParser.parseCreate,
    "GETQUOTA": GrammarParser.parseGetQuota,
    "SETQUOTA": GrammarParser.parseSetQuota,
    "GETQUOTAROOT": GrammarParser.parseGetQuotaRoot,
]

// MARK: Top-level parser

extension GrammarParser {

    static func parseTaggedCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try composite(buffer: &buffer, tracker: tracker, { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let command = try self.parseCommand(buffer: &buffer, tracker: tracker)
            return TaggedCommand(tag: tag, command: command)
        })
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try parseFromLookupTable(buffer: &buffer, tracker: tracker, parsers: commandParsers)
    }
}

// MARK: - Command parsers
extension GrammarParser {

    static func parseCommandAuth_urlFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseAString(buffer: &buffer, tracker: tracker)
        })
        return .urlFetch(array)
    }

    static func parseGetQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try space(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            return .getQuota(quotaRoot)
        }
    }

    static func parseSetQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try space(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let quotaLimits = try parseQuotaLimits(buffer: &buffer, tracker: tracker)
            return .setQuota(quotaRoot, quotaLimits)
        }
    }

    static func parseGetQuotaRoot(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            return .getQuotaRoot(mailbox)
        }
    }

    // authenticate  = "AUTHENTICATE" SP auth-type [SP (base64 / "=")] *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let authMethod = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let parseInitialClientResponse = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> InitialClientResponse in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseInitialClientResponse(buffer: &buffer, tracker: tracker)
            })
            return .authenticate(method: authMethod, initialClientResponse: parseInitialClientResponse)
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SelectParameter] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            }
            return .select(mailbox, params ?? [])
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
            return .rename(from: from, to: to, params: params)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? [:]
            return .examine(mailbox, params)
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> [StoreModifier] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            try space(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    static func parseEsearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        .esearch(try parseEsearchOptions(buffer: &buffer, tracker: tracker))
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseCapability(buffer: &buffer, tracker: tracker)
        }
        return .enable(capabilities)
    }

    // id = "ID" SP id-params-list
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try space(buffer: &buffer, tracker: tracker)
            return .id(try parseIDParamsList(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseCommandAuth_getMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try space(buffer: &buffer, tracker: tracker)
        let options = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> [MetadataOption] in
            let options = try self.parseMetadataOptions(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            return options
        }) ?? []
        let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        try space(buffer: &buffer, tracker: tracker)
        let entries = try self.parseEntries(buffer: &buffer, tracker: tracker)
        return .getMetadata(options: options, mailbox: mailbox, entries: entries)
    }

    static func parseCommandAuth_setMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try space(buffer: &buffer, tracker: tracker)
        let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        try space(buffer: &buffer, tracker: tracker)
        let list = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
        return .setMetadata(mailbox: mailbox, entries: list)
    }

    static func parseCommandAuth_resetKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        let _mailbox = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> MailboxName in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseMailbox(buffer: &buffer, tracker: tracker)
        })

        // don't bother parsing mechanisms if there's no mailbox
        guard let mailbox = _mailbox else {
            return .resetKey(mailbox: nil, mechanisms: [])
        }

        let mechanisms = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UAuthMechanism in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
        })
        return .resetKey(mailbox: mailbox, mechanisms: mechanisms)
    }

    static func parseCommandAuth_genURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> RumpURLAndMechanism in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseURLRumpMechanism(buffer: &buffer, tracker: tracker)
        })
        return .genURLAuth(array)
    }

}
