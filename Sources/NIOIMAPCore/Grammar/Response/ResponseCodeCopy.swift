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
/// - Note: This type uses `[UIDRange]` over `UIDSet` as it's important to preserve the array ordering
/// so that the source UIDs can be matched to destination UIDs.
public struct ResponseCodeCopy: Equatable {
    /// The `UIDValidity` of the destination mailbox
    public var destinationUIDValidity: Int

    /// The message UIDs in the source mailbox.
    public var sourceUIDs: [UIDRange]

    /// The copied message UIDs in the destination mailbox.
    public var destinationUIDs: [UIDRange]

    /// Creates a new `ResponseCodeCopy`.
    /// - parameter destinationUIDValidity: The `UIDValidity` of the destination mailbox.
    /// - parameter sourceUIDs: The message UIDs in the source mailbox.
    /// - parameter destinationUIDs: The copied message UIDs in the destination mailbox.
    public init(destinationUIDValidity: Int, sourceUIDs: [UIDRange], destinationUIDs: [UIDRange]) {
        self.destinationUIDValidity = destinationUIDValidity
        self.sourceUIDs = sourceUIDs
        self.destinationUIDs = destinationUIDs
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeResponseCodeCopy(_ data: ResponseCodeCopy) -> Int {
        self._writeString("COPYUID \(data.destinationUIDValidity) ") +
            self.writeUIDRangeArray(data.sourceUIDs) +
            self.writeSpace() +
            self.writeUIDRangeArray(data.destinationUIDs)
    }

    @discardableResult private mutating func writeUIDRangeArray(_ array: [UIDRange]) -> Int {
        self.writeArray(array, separator: ",", parenthesis: false) { (element, self) in
            self.writeUIDRange(element)
        }
    }
}
