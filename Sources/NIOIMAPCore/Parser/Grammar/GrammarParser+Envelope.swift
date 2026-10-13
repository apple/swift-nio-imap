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

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

/// RFC 3501 §7.4.2 group markers, classified once.
private enum AddressListToken {
    /// host NIL, mailbox = group name
    case groupStart(EmailAddress, name: ByteBuffer)
    /// host NIL, mailbox NIL
    case groupEnd
    case mailbox(EmailAddress)

    init(_ address: EmailAddress) {
        switch (address.host, address.mailbox) {
        case (nil, let name?):
            self = .groupStart(address, name: name)
        case (nil, nil):
            self = .groupEnd
        case (.some, _):
            self = .mailbox(address)
        }
    }
}

/// Group awaiting its end marker. Members are `EmailAddress`, so nesting is unrepresentable here.
private struct OpenGroup {
    var start: EmailAddress
    var name: ByteBuffer
    var members: [EmailAddress] = []
}

extension GrammarParser {
    /// Folds the flat address list into groups. Total over malformed input, lossless, never nests:
    /// a group exists only when a start and an end marker bracket it. Otherwise its markers are
    /// dropped (stray end) or demoted to plain addresses (unclosed start).
    func parseEnvelopeEmailAddressGroups(_ addresses: [EmailAddress]) -> [EmailAddressListElement] {
        var results: [EmailAddressListElement] = []
        var open: OpenGroup?

        for address in addresses {
            // `take()` leaves `open` nil, so the case owning the group appends in place.
            switch (AddressListToken(address), open.take()) {
            case (.groupStart(let start, let name), nil):
                open = OpenGroup(start: start, name: name)
            case (.groupStart(let start, let name), let unclosed?):
                results.append(contentsOf: Self.demote(unclosed))
                open = OpenGroup(start: start, name: name)
            case (.groupEnd, nil):
                continue  // stray end carries no data
            case (.groupEnd, let group?):
                results.append(Self.close(group))
            case (.mailbox(let address), nil):
                results.append(.singleAddress(address))
            case (.mailbox(let address), var group?):
                group.members.append(address)
                open = group
            }
        }

        guard let unclosed = open else { return results }
        results.append(contentsOf: Self.demote(unclosed))
        return results
    }

    /// Unclosed group: start marker as-is (host NIL), then members, all top level.
    /// E.g. `start(Team), alice` → `[single(Team), single(alice)]`.
    private static func demote(_ group: OpenGroup) -> [EmailAddressListElement] {
        [.singleAddress(group.start)] + group.members.map { .singleAddress($0) }
    }

    /// Bracketed group. Start marker's `personName` is dropped (RFC 3501: NIL).
    private static func close(_ group: OpenGroup) -> EmailAddressListElement {
        .group(
            EmailAddressGroup(
                groupName: group.name,
                sourceRoot: group.start.sourceRoot,
                children: group.members.map { .singleAddress($0) }
            )
        )
    }

    // reusable for a lot of the env-* types
    func parseEnvelopeEmailAddresses(buffer: inout ParseBuffer, tracker: StackTracker) throws -> [EmailAddress] {
        try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try PL.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseEmailAddress(buffer: &buffer, tracker: tracker)
        }
        try PL.parseFixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    func parseOptionalEnvelopeEmailAddresses(
        buffer: inout ParseBuffer,
        tracker: StackTracker
    ) throws -> [EmailAddressListElement] {
        func parseOptionalEnvelopeEmailAddresses_nil(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> [EmailAddress] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        func parseOptionalEnvelopeEmailAddresses_emptyList(
            buffer: inout ParseBuffer,
            tracker: StackTracker
        ) throws -> [EmailAddress] {
            // Some servers emit `()` instead of `NIL` for empty addr-list fields.
            // This is non-conformant per RFC 3501 but seen in practice.
            try PL.parseFixedString("()", buffer: &buffer, tracker: tracker)
            return []
        }
        let addresses = try PL.parseOneOf(
            parseEnvelopeEmailAddresses,
            parseOptionalEnvelopeEmailAddresses_nil,
            parseOptionalEnvelopeEmailAddresses_emptyList,
            buffer: &buffer,
            tracker: tracker
        )

        return self.parseEnvelopeEmailAddressGroups(addresses)
    }

    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    func parseEmailAddress(buffer: inout ParseBuffer, tracker: StackTracker) throws -> EmailAddress {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EmailAddress in
            try PL.parseOptional(buffer: &buffer, tracker: tracker, parser: PL.parseSpaces)
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

    func parseMessageID(buffer: inout ParseBuffer, tracker: StackTracker) throws -> MessageID? {
        if let parsed = try self.parseNString(buffer: &buffer, tracker: tracker) {
            let string = try ParserLibrary.parseBufferAsUTF8(parsed)
            return .init(string)
        }
        return nil
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    func parseEnvelope(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Envelope {
        try PL.composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try PL.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap {
                InternetMessageDate(String(buffer: $0))
            }
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
