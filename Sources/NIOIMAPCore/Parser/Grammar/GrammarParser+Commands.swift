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

fileprivate let commandParsers: [String: (inout ByteBuffer, StackTracker) throws -> Command] = [
    "CAPABILITY" : { _, _ in return .capability },
    "LOGOUT" : { _, _ in return .logout },
    "NOOP" : { _, _ in return .noop },
    "STARTTLS" : { _, _ in return .starttls },
    "CHECK" : { _, _ in return .check },
    "CLOSE" : { _, _ in return .close },
    "EXPUNGE" : { _, _ in return .expunge },
    "UNSELECT" : { _, _ in return .unselect },
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
    "IDLE": GrammarParser.parseIdleStart,
    "NAMESPACE": GrammarParser.parseNamespaceCommand,
    "UID": GrammarParser.parseUid,
    "FETCH": GrammarParser.parseFetch,
    "LOGIN": GrammarParser.parseLogin,
    "AUTHENTICATE": GrammarParser.parseAuthenticate,
    "CREATE": GrammarParser.parseCreate,
    "GETQUOTA": GrammarParser.parseGetQuota,
    "SETQUOTA": GrammarParser.parseSetQuota,
    "GETQUOTAROOT": GrammarParser.parseGetQuotaRoot,
]

extension GrammarParser {

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

    static func tableParser<T>(buffer: inout ByteBuffer, tracker: StackTracker, parsers: [String: (inout ByteBuffer, StackTracker) throws -> T]) throws -> T {
        let save = buffer
        do {
            let word = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAlpha
            }.uppercased()
            guard let parser = parsers[word] else {
                throw ParserError(hint: "Didn't find parser for \(word)")
            }
            return try parser(&buffer, tracker)
        } catch {
            buffer = save
            throw error
        }
    }

    static func parseCommandAuth_urlFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseAString(buffer: &buffer, tracker: tracker)
        })
        return .urlFetch(array)
    }

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
        try tableParser(buffer: &buffer, tracker: tracker, parsers: commandParsers)
    }
}
