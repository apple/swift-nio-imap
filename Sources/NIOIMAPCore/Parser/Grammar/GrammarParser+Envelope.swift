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
    static func parseEnvelopeAddressGroups(_ addresses: [Address]) -> [AddressListElement] {
        
        var results: [AddressListElement] = []
        var stack: [AddressGroup] = []
        
        for address in addresses {
            
            if address.host == nil , let name = address.mailbox { // start of group
                stack.append(AddressGroup(groupName: name, sourceRoot: address.sourceRoot, children: []))
            } else if address.host == nil { // end of group
                let group = stack.popLast()!
                if stack.last == nil {
                    results.append(.group(group))
                } else {
                    stack[stack.count - 1].children.append(.group(group))
                }
            } else { // normal address
                if stack.last == nil {
                    results.append(.address(address))
                } else {
                    stack[stack.count-1].children.append(.address(address))
                }
            }
            
        }
        
        return results
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        try fixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseAddress(buffer: &buffer, tracker: tracker)
        }
        try fixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [AddressListElement] {
        func parseOptionalEnvelopeAddresses_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        let addresses = try oneOf([
            parseEnvelopeAddresses,
            parseOptionalEnvelopeAddresses_nil,
        ], buffer: &buffer, tracker: tracker)

        return self.parseEnvelopeAddressGroups(addresses)
    }

    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseAddress(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Address {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Address in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return Address(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)
        }
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Envelope {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try space(buffer: &buffer, tracker: tracker)
            let subject = try self.parseNString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let from = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let sender = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let replyTo = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let to = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let cc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let bcc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let inReplyTo = try self.parseNString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let messageID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try fixedString(")", buffer: &buffer, tracker: tracker)
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
