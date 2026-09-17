//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOIMAP

/// A summary of a fetched message, including its envelope and flags.
struct MessageInfo: Sendable, Hashable, Encodable {
    /// The UID of the message.
    var uid: UID
    /// The RFC 2822 date string from the envelope.
    var date: String?
    /// The date as seconds since the Unix epoch.
    var dateSeconds: Double?
    /// The subject line of the message.
    var subject: String?
    /// The sender of the message.
    var from: String?
    /// The primary recipients of the message.
    var to: String?
    /// The carbon-copy recipients of the message.
    var cc: String?
    /// The `Message-ID` header value.
    var messageID: String?
    /// The `In-Reply-To` header value.
    var inReplyTo: String?
    /// The flags set on the message.
    var flags: [String]

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(UInt32(uid), forKey: .uid)
        try c.encodeIfPresent(date, forKey: .date)
        try c.encodeIfPresent(dateSeconds, forKey: .dateSeconds)
        try c.encodeIfPresent(subject, forKey: .subject)
        try c.encodeIfPresent(from, forKey: .from)
        try c.encodeIfPresent(to, forKey: .to)
        try c.encodeIfPresent(cc, forKey: .cc)
        try c.encodeIfPresent(messageID, forKey: .messageID)
        try c.encodeIfPresent(inReplyTo, forKey: .inReplyTo)
        try c.encode(flags, forKey: .flags)
    }

    enum CodingKeys: String, CodingKey {
        case uid
        case date
        case dateSeconds
        case subject
        case from
        case to
        case cc
        case messageID
        case inReplyTo
        case flags
    }
}

extension MessageInfo {
    init?(
        uid: UID,
        attributes: [MessageAttribute]
    ) {
        var uid: UID = uid
        var envelope: Envelope?
        var flags: [Flag]?

        for attribute in attributes {
            switch attribute {
            case .uid(let u):
                uid = u
            case .envelope(let e):
                envelope = e
            case .flags(let f):
                flags = f
            default:
                break
            }
        }
        guard
            let envelope,
            let flags
        else { return nil }
        self.init(uid: uid, envelope: envelope, flags: flags)
    }

    init(uid: UID, envelope: Envelope, flags: [Flag]) {
        self.uid = uid
        let date = envelope.date.map { String($0) }
        self.date = date
        if let date, let seconds = InternetMessageDate(date).parse() {
            self.dateSeconds = seconds.timeIntervalSince1970
        }
        self.subject = envelope.subject.map { String(buffer: $0) }
        self.from = envelope.from.isEmpty ? nil : String(envelope.from)
        self.to = envelope.to.isEmpty ? nil : String(envelope.to)
        self.cc = envelope.cc.isEmpty ? nil : String(envelope.cc)
        self.messageID = envelope.messageID.map { String($0) }
        self.inReplyTo = envelope.inReplyTo.map { String($0) }
        self.flags = flags.map { String($0) }
    }
}

extension String {
    fileprivate init(_ list: [EmailAddressListElement]) {
        self =
            list
            .map {
                String($0)
            }
            .joined(separator: ", ")
    }

    fileprivate init(_ listElement: EmailAddressListElement) {
        switch listElement {
        case .singleAddress(let address):
            switch (address.personName, address.mailbox, address.host) {
            case (let name?, let mailbox?, let host?):
                self = "\"\(String(buffer: name))\" <\(String(buffer: mailbox))@\(String(buffer: host))>"
            case (_, let mailbox?, let host?):
                self = "\(String(buffer: mailbox))@\(String(buffer: host))"
            default:
                self = "<>"
            }
        case .group(let group):
            let groupName = String(buffer: group.groupName)
            self = "\"\(groupName)\": {\(String(group.children))}"
        }
    }
}
