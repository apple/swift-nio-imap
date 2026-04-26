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

/// A range specifier for the `PARTIAL` extension enabling paged results.
///
/// The `PARTIAL` extension (RFC 9394) allows clients to request `SEARCH` and `FETCH` results
/// in fixed-size pages, either from the beginning (`.first`) or end (`.last`) of the result set.
/// Enables efficient pagination of large result sets without retrieving the entire list.
///
/// The two forms are:
/// - `.first`: Requests N results starting from the lowest UID (beginning)
/// - `.last`: Requests N results starting from the highest UID (end), encoded with negative offsets
///
/// - SeeAlso: [RFC 9394 IMAP PARTIAL Extension for Paged Results](https://datatracker.ietf.org/doc/html/rfc9394)
public enum PartialRange: Hashable, Sendable {
    /// A range relative to the oldest (lowest UID) message.
    ///
    /// Aka. `partial-range-first`.
    case first(SequenceRange)
    /// A range relative to the newest (highest UID) message.
    ///
    /// Encoded as a negative number.
    ///
    /// Aka. `partial-range-last`.
    case last(SequenceRange)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writePartialRange(_ range: PartialRange) -> Int {
        switch range {
        case .first(let r):
            return self.writeSequenceNumberOrWildcard(r.range.lowerBound) + self.writeString(":")
                + self.writeSequenceNumberOrWildcard(r.range.upperBound)
        case .last(let r):
            return self.writeString("-") + self.writeSequenceNumberOrWildcard(r.range.lowerBound)
                + self.writeString(":-") + self.writeSequenceNumberOrWildcard(r.range.upperBound)
        }
    }
}
