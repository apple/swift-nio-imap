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

import struct NIO.ByteBuffer

/// An RFC 2822 electronic mail address with structured components.
///
/// This type represents an address as returned in the `ENVELOPE` structure of a `FETCH` response.
/// The `ENVELOPE` address format breaks email addresses into four distinct components to help applications
/// display mail headers consistently and reliably.
///
/// Each field is optional (may be NIL in the protocol). The complete email address is typically
/// constructed by combining these fields, but applications should handle partial or missing components gracefully.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (ENVELOPE)
/// S: * 1 FETCH (ENVELOPE (NIL "Alice Smith" "alice" "example.com" ...))
/// ```
///
/// This response contains an address with nil at-domain-list, personName "Alice Smith", mailbox "alice", and host "example.com".
///
/// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
public struct EmailAddress: Hashable, Sendable {
    /// The addressee's personal name (may be an alias).
    public var personName: ByteBuffer?

    /// The SMTP at-domain-list (source-root).
    public var sourceRoot: ByteBuffer?

    /// The mailbox containing the message.
    public var mailbox: ByteBuffer?

    /// The host name of the server that sent the message.
    public var host: ByteBuffer?

    /// Creates a new `EmailAddress`.
    /// - parameter personName: The addressee's personal name (may be an alias).
    /// - parameter sourceRoot: The SMTP at-domain-list (source-root).
    /// - parameter mailbox: The mailbox the message.
    /// - parameter host: The host name of the server that sent the message.
    public init(personName: ByteBuffer?, sourceRoot: ByteBuffer?, mailbox: ByteBuffer?, host: ByteBuffer?) {
        self.personName = personName
        self.sourceRoot = sourceRoot
        self.mailbox = mailbox
        self.host = host
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEmailAddress(_ address: EmailAddress) -> Int {
        self.writeString("(") + self.writeNString(address.personName) + self.writeSpace()
            + self.writeNString(address.sourceRoot) + self.writeSpace() + self.writeNString(address.mailbox)
            + self.writeSpace() + self.writeNString(address.host) + self.writeString(")")
    }
}
