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
    static func parseEnvelopeEmailAddressGroups(_ addresses: [EmailAddress]) -> [EmailAddressListElement] {
        var results: [EmailAddressListElement] = []
        var stack: [EmailAddressGroup] = []

        for address in addresses {
            if address.host == nil, let name = address.mailbox { // start of group
                stack.append(EmailAddressGroup(groupName: name, sourceRoot: address.sourceRoot, children: []))
            } else if address.host == nil { // end of group
                let group = stack.popLast()!
                if stack.last == nil {
                    results.append(.group(group))
                } else {
                    stack[stack.count - 1].children.append(.group(group))
                }
            } else { // normal address
                if stack.last == nil {
                    results.append(.singleAddress(address))
                } else {
                    stack[stack.count - 1].children.append(.singleAddress(address))
                }
            }
        }

        return results
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeEmailAddresses(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [EmailAddress] {
        try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseEmailAddress(buffer: &buffer, tracker: tracker)
        }
        try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeEmailAddresses(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [EmailAddressListElement] {
        func parseOptionalEnvelopeEmailAddresses_nil(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [EmailAddress] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        let addresses = try PL.parseOneOf(
            parseEnvelopeEmailAddresses,
            parseOptionalEnvelopeEmailAddresses_nil,
            buffer: &buffer,
            tracker: tracker
        )

        return self.parseEnvelopeEmailAddressGroups(addresses)
    }

    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseEmailAddress(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EmailAddress {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EmailAddress in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return EmailAddress(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)
        }
    }

    static func parseMessageID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageID? {
        if let parsed = try self.parseNString(buffer: &buffer, tracker: tracker) {
            guard let string = String(validatingUTF8Bytes: parsed.readableBytesView) else {
                throw ParserError()
            }
            return .init(rawValue: string)
        }
        return nil
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Envelope {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { InternetMessageDate(String(buffer: $0)) }
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let subject = try self.parseNString(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let from = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let sender = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let replyTo = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let to = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let cc = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let bcc = try self.parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let inReplyTo = try self.parseMessageID(buffer: &buffer, tracker: tracker)
            try PL.parseSpaces(buffer: &buffer, tracker: tracker)
            let messageID = try self.parseMessageID(buffer: &buffer, tracker: tracker)
            try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return Envelope(
                date: date,
                subject: subject,
                from: from,
                sender: sender,
                reply: replyTo,
                to: to,
                cc: cc,
                bcc: bcc,
                inReplyTo: inReplyTo,
                messageID: messageID
            )
        }
    }
}
