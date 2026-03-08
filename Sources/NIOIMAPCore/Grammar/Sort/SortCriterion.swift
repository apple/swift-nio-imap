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

/// Represents a sort criterion for the `SORT` command.
///
/// Sort criteria define the order in which messages should be returned from a `SORT`
/// or `UID SORT` command. Multiple criteria can be specified to create a multi-level
/// sort, where later criteria are used as tie-breakers when earlier criteria produce
/// equal values.
///
/// The `SORT` extension is defined in [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256).
/// The display sort extension (``displayFrom`` and ``displayTo``) is defined in
/// [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957).
///
/// ### Examples
///
/// ```
/// C: A001 SORT (DATE) UTF-8 ALL
/// S: * SORT 5 3 1 2 4
/// S: A001 OK SORT completed
/// ```
///
/// Use ``reverse(_:)`` to reverse the sort order:
///
/// ```
/// C: A002 SORT (REVERSE DATE SUBJECT) UTF-8 UNSEEN
/// S: * SORT 4 2 1 3 5
/// S: A002 OK SORT completed
/// ```
///
/// ## Related Types
///
/// - ``Command/sort(criteria:charset:key:returnOptions:)`` and ``Command/uidSort(criteria:charset:key:returnOptions:)``: Commands that perform sorting
/// - ``SearchKey``: Criteria for filtering messages before sorting
/// - ``SearchReturnOption``: Options controlling the format of sort results
///
/// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256), [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957)
public indirect enum SortCriterion: Hashable, Sendable {
    /// Sort by internal date and time of the message.
    ///
    /// The internal date is when the message was received by the server, not the
    /// `Date` header value. This corresponds to the `INTERNALDATE` message attribute.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case arrival

    /// Sort by the first address in the `Cc` header.
    ///
    /// Uses the mailbox portion (addr-mailbox) of the first address. If the `Cc`
    /// header is absent or contains no addresses, sorts as the empty string.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case cc

    /// Sort by the sent date of the message.
    ///
    /// Uses the `Date` header value, not the internal date. If the `Date` header
    /// is missing or cannot be parsed, the internal date is used instead.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case date

    /// Sort by the first address in the `From` header.
    ///
    /// Uses the mailbox portion (addr-mailbox) of the first address. If the `From`
    /// header is absent or contains no addresses, sorts as the empty string.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case from

    /// Sort by the size of the message in octets.
    ///
    /// This corresponds to the `RFC822.SIZE` message attribute.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case size

    /// Sort by the base subject text.
    ///
    /// The subject is processed according to [RFC 5256 Section 2.1](https://datatracker.ietf.org/doc/html/rfc5256#section-2.1)
    /// to strip reply prefixes (e.g., "Re:", "Fwd:") and normalize whitespace before comparison.
    case subject

    /// Sort by the first address in the `To` header.
    ///
    /// Uses the mailbox portion (addr-mailbox) of the first address. If the `To`
    /// header is absent or contains no addresses, sorts as the empty string.
    /// From [RFC 5256 Section 2.2](https://datatracker.ietf.org/doc/html/rfc5256#section-2.2).
    case to

    /// Sort by the display name from the `From` header.
    ///
    /// If the first address has a display name, uses that; otherwise falls back
    /// to the mailbox portion like ``from``.
    /// From [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957).
    case displayFrom

    /// Sort by the display name from the `To` header.
    ///
    /// If the first address has a display name, uses that; otherwise falls back
    /// to the mailbox portion like ``to``.
    /// From [RFC 5957](https://datatracker.ietf.org/doc/html/rfc5957).
    case displayTo

    /// Reverse the sort order of the following criterion.
    ///
    /// The `REVERSE` modifier inverts the sort order of its associated criterion.
    /// For example, ``reverse(_:)`` with ``date`` sorts messages newest-first
    /// instead of oldest-first.
    ///
    /// - Parameter criterion: The criterion whose sort order should be reversed.
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
