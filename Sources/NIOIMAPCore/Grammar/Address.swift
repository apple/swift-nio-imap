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

/// IMAPv4 `address`
public struct Address: Equatable {
    public var name: ByteBuffer?
    public var adl: ByteBuffer?
    public var mailbox: ByteBuffer?
    public var host: ByteBuffer?

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
