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
    public var uidValidity: Int?

    public init(tag: ByteBuffer, mailbox: MailboxName? = nil, uidValidity: Int? = nil) {
        self.tag = tag
        self.mailbox = mailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchCorrelator(_ correlator: SearchCorrelator) -> Int {
        var result = self.writeString(" (TAG ") + self.writeTagString(correlator.tag)
        if let mailbox = correlator.mailbox {
            result += self.writeString(" MAILBOX ") + self.writeMailbox(mailbox)
        }
        if let uidValidity = correlator.uidValidity {
            result += self.writeString(" UIDVALIDITY \(uidValidity)")
        }
        result += self.writeString(")")
        return result
    }
}
