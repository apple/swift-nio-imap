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

/// RFC 5092
public struct IMailboxReference: Equatable {
    public var encodedMailbox: EncodedMailbox

    public var uidValidity: UIDValidity?

    public init(encodeMailbox: EncodedMailbox, uidValidity: UIDValidity? = nil) {
        self.encodedMailbox = encodeMailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMailboxReference(_ ref: IMailboxReference) -> Int {
        self.writeEncodedMailbox(ref.encodedMailbox) +
            self.writeIfExists(ref.uidValidity) { value in
                self.writeString(";UIDVALIDITY=") + self.writeUIDValidity(value)
            }
    }
}
