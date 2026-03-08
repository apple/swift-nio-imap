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

/// Represents a sort criterion as defined in RFC 5256 §3.
///
/// Sort criteria define the order in which messages should be returned
/// from a SORT command.
public indirect enum SortCriterion: Hashable, Sendable {
    /// Sort by internal date and time of the message.
    case arrival

    /// Sort by the first address in the Cc header.
    case cc

    /// Sort by the sent date of the message (Date header).
    case date

    /// Sort by the first address in the From header.
    case from

    /// Sort by the size of the message in octets.
    case size

    /// Sort by the Subject header, with stripping of Re: etc.
    case subject

    /// Sort by the first address in the To header.
    case to

    /// Sort by the display name of the From header (RFC 5957).
    case displayFrom

    /// Sort by the display name of the To header (RFC 5957).
    case displayTo

    /// Reverse the sort order of the following sort criterion.
    case reverse(SortCriterion)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSortCriteria(_ criteria: [SortCriterion]) -> Int {
        self.writeString("(")
            + self.writeArray(criteria, parenthesis: false) { (criterion, buffer) -> Int in
                buffer.writeSortCriterion(criterion)
            } + self.writeString(")")
    }

    @discardableResult mutating func writeSortCriterion(_ criterion: SortCriterion) -> Int {
        switch criterion {
        case .arrival:
            return self.writeString("ARRIVAL")
        case .cc:
            return self.writeString("CC")
        case .date:
            return self.writeString("DATE")
        case .from:
            return self.writeString("FROM")
        case .size:
            return self.writeString("SIZE")
        case .subject:
            return self.writeString("SUBJECT")
        case .to:
            return self.writeString("TO")
        case .displayFrom:
            return self.writeString("DISPLAYFROM")
        case .displayTo:
            return self.writeString("DISPLAYTO")
        case .reverse(let inner):
            return self.writeString("REVERSE ") + self.writeSortCriterion(inner)
        }
    }
}
