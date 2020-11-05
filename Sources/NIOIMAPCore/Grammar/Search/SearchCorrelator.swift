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

/// RFC 6237 search-correlator
public struct SearchCorrelator: Equatable {
    /// The original option from RFC4466
    public var tag: ByteBuffer

    /// Required iff using RFC 6237
    public var mailbox: MailboxName?

    /// Required iff using RFC 6237
    public var uidValidity: UIDValidity?

    public init(tag: ByteBuffer, mailbox: MailboxName? = nil, uidValidity: UIDValidity? = nil) {
        self.tag = tag
        self.mailbox = mailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchCorrelator(_ correlator: SearchCorrelator) -> Int {
        self.writeString(" (TAG ") +
            self.writeTagString(correlator.tag) +
            self.writeIfExists(correlator.mailbox) { mailbox in
                self.writeString(" MAILBOX ") + self.writeMailbox(mailbox)
            } +
            self.writeIfExists(correlator.uidValidity) { uidValidity in
                self.writeString(" UIDVALIDITY ") + self.writeUIDValidity(uidValidity)
            } +
            self.writeString(")")
    }
}
