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

/// Wraps the modification time of a message that is returned as part of a `.fetch` command.
public struct FetchModificationResponse: Equatable {
    /// The date that the message was last modified.
    public var modificationSequenceValue: ModificationSequenceValue

    /// Creates a new `FetchModificationResponse`.
    /// - parameter modifierSequenceValue: The date that the message was last modified.
    public init(modifierSequenceValue: ModificationSequenceValue) {
        self.modificationSequenceValue = modifierSequenceValue
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeFetchModificationResponse(_ resp: FetchModificationResponse) -> Int {
        self._writeString("MODSEQ (") +
            self.writeModificationSequenceValue(resp.modificationSequenceValue) +
            self._writeString(")")
    }
}
