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

/// Matches the `UIDSet` of the messages in the source mailbox to the `UIDSet` of the
/// copied messages in the destination mailbox.
public struct ResponseCodeCopy: Equatable {
    /// The `UIDValidity` of the destination mailbox
    public var destinationUIDValidity: Int

    /// The message UIDs in the source mailbox.
    public var sourceUidSet: UIDSet

    /// The copied message UIDs in the destination mailbox.
    public var destinationUidSet: UIDSet

    /// Creates a new `ResponseCodeCopy`.
    /// - parameter num: The `UIDValidity` of the destination mailbox.
    /// - parameter set1: The message UIDs in the source mailbox.
    /// - parameter set2: The copied message UIDs in the destination mailbox.
    public init(num: Int, set1: UIDSet, set2: UIDSet) {
        self.destinationUIDValidity = num
        self.sourceUidSet = set1
        self.destinationUidSet = set2
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseCodeCopy(_ data: ResponseCodeCopy) -> Int {
        self.writeString("COPYUID \(data.destinationUIDValidity) ") +
            self.writeUIDSet(data.sourceUidSet) +
            self.writeSpace() +
            self.writeUIDSet(data.destinationUidSet)
    }
}
