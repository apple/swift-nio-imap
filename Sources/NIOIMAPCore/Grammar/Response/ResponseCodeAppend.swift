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

/// Returned after a successful `.uidAppend` command. Provides the new identifiers
/// of the appended messages, and the uid validity of the destination mailbox. Note that multiple
/// appends ae only supported if the capability `MULTISEARCH` is enabled.
public struct ResponseCodeAppend: Equatable {
    /// The UID validity of the destination mailbox.
    public var uidValidity: UIDValidity

    /// The UIDs of the messages after they have been appended.
    public var uids: MessageIdentifierSetNonEmpty<UID>

    /// Creates a new `ResponseCodeAppend`.
    /// - parameter uidValidity: The UID validity of the destination mailbox.
    /// - parameter uids: The UIDs of the messages after they have been appended.
    public init(uidValidity: UIDValidity, uids: MessageIdentifierSetNonEmpty<UID>) {
        self.uidValidity = uidValidity
        self.uids = uids
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseCodeAppend(_ data: ResponseCodeAppend) -> Int {
        self.writeString("APPENDUID \(data.uidValidity.rawValue) ") +
            self.writeUIDSet(data.uids)
    }
}
