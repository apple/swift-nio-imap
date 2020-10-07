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

/// RFC 5092
public struct EncodedMailbox: Equatable {
    public var mailbox: String

    public init(mailbox: String) {
        self.mailbox = mailbox
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedMailbox(_ type: EncodedMailbox) -> Int {
        self.writeString(type.mailbox)
    }
}
