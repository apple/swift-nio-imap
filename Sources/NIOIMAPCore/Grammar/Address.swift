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

/// An address structure is a parenthesized list that describes an
/// electronic mail address.
public struct Address: Equatable {
    /// The addressee's personal name (may be an alias).
    public var name: ByteBuffer?

    /// The SMTP at-domain-list.
    public var adl: ByteBuffer?

    /// The mailbox the message.
    public var mailbox: ByteBuffer?

    /// The host name of the server that sent the message.
    public var host: ByteBuffer?

    /// Creates a new `Address`.
    /// - parameter name: The addressee's personal name (may be an alias).
    /// - parameter adl: The SMTP at-domain-list.
    /// - parameter mailbox: The mailbox the message.
    /// - parameter host: The host name of the server that sent the message.
    public init(name: ByteBuffer?, adl: ByteBuffer?, mailbox: ByteBuffer?, host: ByteBuffer?) {
        self.name = name
        self.adl = adl
        self.mailbox = mailbox
        self.host = host
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAddress(_ address: Address) -> Int {
        self.writeString("(") +
            self.writeNString(address.name) +
            self.writeSpace() +
            self.writeNString(address.adl) +
            self.writeSpace() +
            self.writeNString(address.mailbox) +
            self.writeSpace() +
            self.writeNString(address.host) +
            self.writeString(")")
    }
}
