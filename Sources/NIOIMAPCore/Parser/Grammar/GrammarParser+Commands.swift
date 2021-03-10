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
    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let type = try oneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect,
                self.parseCommandQuota,
            ], buffer: &buffer, tracker: tracker)
            return TaggedCommand(tag: tag, command: type)
        }
    }

    // command-any     = "CAPABILITY" / "LOGOUT" / "NOOP" / enable / x-command / id
    static func parseCommandAny(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAny_capability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return .capability
        }

        func parseCommandAny_logout(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("LOGOUT", buffer: &buffer, tracker: tracker)
            return .logout
        }

        func parseCommandAny_noop(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("NOOP", buffer: &buffer, tracker: tracker)
            return .noop
        }

        func parseCommandAny_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let id = try self.parseID(buffer: &buffer, tracker: tracker)
            return .id(id)
        }

        func parseCommandAny_enable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let enable = try self.parseEnable(buffer: &buffer, tracker: tracker)
            return enable
        }

        return try oneOf([
            parseCommandAny_noop,
            parseCommandAny_logout,
            parseCommandAny_capability,
            parseCommandAny_id,
            parseCommandAny_enable,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-auth    = append / create / delete / examine / list / lsub /
    //                   Namespace-Command /
    //                   rename / select / status / subscribe / unsubscribe /
    //                   idle
    // RFC 6237
    // command-auth =/  esearch
    static func parseCommandAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAuth_getMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("GETMETADATA", buffer: &buffer, tracker: tracker)
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

        func parseCommandAuth_setMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("SETMETADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .setMetadata(mailbox: mailbox, entries: list)
        }

        func parseCommandAuth_resetKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("RESETKEY", buffer: &buffer, tracker: tracker)
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

        func parseCommandAuth_generateAuthorizationURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("GENURLAUTH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> RumpURLAndMechanism in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseURLRumpMechanism(buffer: &buffer, tracker: tracker)
            })
            return .generateAuthorizationURL(array)
        }

        func parseCommandAuth_urlFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("URLFETCH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return .urlFetch(array)
        }

        return try oneOf([
            self.parseCreate,
            self.parseDelete,
            self.parseExamine,
            self.parseList,
            self.parseLSUB,
            self.parseRename,
            self.parseSelect,
            self.parseStatus,
            self.parseSubscribe,
            self.parseUnsubscribe,
            self.parseIdleStart,
            self.parseNamespaceCommand,
            parseCommandAuth_getMetadata,
            parseCommandAuth_setMetadata,
            parseExtendedSearch,
            parseCommandAuth_resetKey,
            parseCommandAuth_generateAuthorizationURL,
            parseCommandAuth_urlFetch,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-nonauth = login / authenticate / "STARTTLS"
    static func parseCommandNonauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandNonauth_starttls(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("STARTTLS", buffer: &buffer, tracker: tracker)
            return .starttls
        }

        return try oneOf([
            self.parseLogin,
            self.parseAuthenticate,
            parseCommandNonauth_starttls,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-select  = "CHECK" / "CLOSE" / "UNSELECT" / "EXPUNGE" / copy / fetch / store /
    //                   uid / search / move
    // RFC 6237
    // command-select =/  esearch
    static func parseCommandSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandSelect_check(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CHECK", buffer: &buffer, tracker: tracker)
            return .check
        }

        func parseCommandSelect_close(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CLOSE", buffer: &buffer, tracker: tracker)
            return .close
        }

        func parseCommandSelect_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge
        }

        func parseCommandSelect_unselect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("UNSELECT", buffer: &buffer, tracker: tracker)
            return .unselect
        }

        return try oneOf([
            parseCommandSelect_check,
            parseCommandSelect_close,
            parseCommandSelect_expunge,
            parseCommandSelect_unselect,
            self.parseCopy,
            self.parseFetch,
            self.parseStore,
            self.parseUid,
            self.parseSearch,
            self.parseMove,
            self.parseExtendedSearch,
        ], buffer: &buffer, tracker: tracker)
    }
}
