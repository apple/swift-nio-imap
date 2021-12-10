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

/// A wrapper to combine a message sequence set and a corresponding UID set.
/// Both are provided in ascending order.
/// Recommended reading RFC 7162 § 3.2.5.2
public struct SequenceMatchData: Hashable {
    /// Set of message numbers corresponding to the UIDs in known-uid-set, in ascending order. * is not allowed.
    public var knownSequenceSet: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>

    /// Set of UIDs corresponding to the messages in known-sequence-set, in ascending order. * is not allowed.
    public var knownUidSet: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>

    // TODO: Enforce ascneding order.
    /// Creates a new `SequenceMatchData`. Note that both `knownSequenceSet` and `knownUidSet`
    /// should be provided in ascending order, though this is not currently enforced.
    /// - parameter knownSequenceSet: Set of message numbers corresponding to the UIDs in known-uid-set, in ascending order. * is not allowed.
    /// - parameter knownUidSet: Set of UIDs corresponding to the messages in known-sequence-set, in ascending order. * is not allowed.
    public init(knownSequenceSet: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>, knownUidSet: LastCommandSet<MessageIdentifierSetNonEmpty<UID>>) {
        self.knownSequenceSet = knownSequenceSet
        self.knownUidSet = knownUidSet
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceMatchData(_ data: SequenceMatchData) -> Int {
        self.writeString("(") +
            self.writeLastCommandSet(data.knownSequenceSet) +
            self.writeSpace() +
            self.writeLastCommandSet(data.knownUidSet) +
            self.writeString(")")
    }
}
