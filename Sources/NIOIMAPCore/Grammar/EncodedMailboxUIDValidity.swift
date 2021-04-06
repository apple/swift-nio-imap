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

/// Provides the `UIDValitiy` for a percent-encoded mailbox. If the `UIDValidity` is present
/// it will be used to ensure the URL is not stale.
public struct EncodedMailboxUIDValidity: Equatable {
    /// The percent-encoded mailbox.
    public var encodedMailbox: EncodedMailbox

    /// The corresponding `UIDValidity`
    public var uidValidity: UIDValidity?

    /// Creates a new `EncodedMailboxUIDValidity`.
    /// - parameter encodeMailbox: The percent-encoded mailbox.
    /// - parameter uidValidity: The corresponding `UIDValidity`
    public init(encodeMailbox: EncodedMailbox, uidValidity: UIDValidity? = nil) {
        self.encodedMailbox = encodeMailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeEncodedMailboxUIDValidity(_ ref: EncodedMailboxUIDValidity) -> Int {
        self.writeEncodedMailbox(ref.encodedMailbox) +
            self.writeIfExists(ref.uidValidity) { value in
                self._writeString(";UIDVALIDITY=") + self.writeUIDValidity(value)
            }
    }
}
