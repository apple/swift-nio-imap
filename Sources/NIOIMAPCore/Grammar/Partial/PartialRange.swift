//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A range for `draft-ietf-extra-imap-partial-04` aka. “Paged SEARCH & FETCH”
///
/// Aka. `partial-range`.
public enum PartialRange: Hashable {
    /// A range relative to the oldest (lowest UID) message.
    ///
    /// Aka. `partial-range-first`.
    case first(SequenceRange)
    /// A range relative to the newest (highest UID) message.
    ///
    /// This is encoded as negative number.
    ///
    /// Aka. `partial-range-last`.
    case last(SequenceRange)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writePartialRange(_ range: PartialRange) -> Int {
        switch range {
        case .first(let r):
            return self.writeSequenceNumberOrWildcard(r.range.lowerBound) +
                self.writeString(":") +
                self.writeSequenceNumberOrWildcard(r.range.upperBound)
        case .last(let r):
            return self.writeString("-") +
                self.writeSequenceNumberOrWildcard(r.range.lowerBound) +
                self.writeString(":-") +
                self.writeSequenceNumberOrWildcard(r.range.upperBound)
        }
    }
}
