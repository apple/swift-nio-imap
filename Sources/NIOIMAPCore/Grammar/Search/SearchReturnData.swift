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

import struct NIO.ByteBuffer

/// Response data returned from a search command using the ESEARCH extension (RFC 4731).
///
/// When a client specifies one or more result options in the `RETURN` clause of a `SEARCH` or `UID SEARCH` command,
/// the server responds with an ESEARCH response containing ``SearchReturnData`` cases corresponding to the
/// requested options. Each case represents a specific type of search result.
///
/// **Requires server capability:** ``Capability/extendedSearch``
///
/// The ESEARCH response can include multiple data elements (e.g., both `MIN` and `COUNT`), and clients should handle
/// each independently. Some result options (like ``count(_:)``) are always present, while others (like ``min(_:)``
/// and ``max(_:)``) are omitted if the search returns no matches.
///
/// ### Examples
///
/// ```
/// S: * ESEARCH (TAG "A001") MIN 2 COUNT 3
/// S: A001 OK SEARCH completed
/// ```
///
/// The line `S: * ESEARCH (TAG "A001") MIN 2 COUNT 3` represents a server response containing two ``SearchReturnData``
/// cases: ``min(_:)`` with value `2` and ``count(_:)`` with value `3`. These are wrapped in an ``ExtendedSearchResponse``.
///
/// ```
/// S: * ESEARCH (TAG "A002") UID ALL 7,10:15,22
/// S: A002 OK SEARCH completed
/// ```
///
/// The `ALL 7,10:15,22` portion represents ``all(_:)`` containing a ``LastCommandSet`` with the matching UIDs.
///
/// - SeeAlso: [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731)
/// - SeeAlso: ``SearchReturnOption``
/// - SeeAlso: ``ExtendedSearchResponse``
public enum SearchReturnData: Hashable, Sendable {
    /// The lowest message number/UID matching the search criteria.
    ///
    /// Returned when `MIN` is included in the `RETURN` clause. Only present if the search
    /// found at least one matching message. The value is either a message number (for `SEARCH`)
    /// or a UID (for `UID SEARCH`).
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case min(UnknownMessageIdentifier)

    /// The highest message number/UID matching the search criteria.
    ///
    /// Returned when `MAX` is included in the `RETURN` clause. Only present if the search
    /// found at least one matching message. The value is either a message number (for `SEARCH`)
    /// or a UID (for `UID SEARCH`).
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case max(UnknownMessageIdentifier)

    /// All message numbers/UIDs matching the search criteria in sequence-set format.
    ///
    /// Returned when `ALL` is included in the `RETURN` clause. Results are represented as
    /// a ``LastCommandSet`` (compact sequence-set notation like `2,10:11`). Only present if the search
    /// found at least one matching message.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case all(LastCommandSet<UnknownMessageIdentifier>)

    /// The count of messages matching the search criteria.
    ///
    /// Returned when `COUNT` is included in the `RETURN` clause. Unlike other result options,
    /// this is REQUIRED and always included in the ESEARCH response, even when the count is zero.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case count(Int)

    /// The highest modification sequence value among all messages being returned.
    ///
    /// Returned when the search is performed with a `MODSEQ` criterion and the server supports
    /// the CONDSTORE extension. This allows clients to track which message state changes were
    /// included in the search results for future synchronization.
    ///
    /// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
    case modificationSequence(ModificationSequenceValue)

    /// A subset of results for paginated search using the PARTIAL extension.
    ///
    /// Returned when the `.partial(_:)`` option is included in the `RETURN` clause. Contains
    /// the requested range and the message numbers/UIDs within that range. The set may be empty
    /// if the requested range is beyond the total number of results.
    ///
    /// - SeeAlso: [RFC 9394](https://datatracker.ietf.org/doc/html/rfc9394)
    case partial(PartialRange, MessageIdentifierSet<UnknownMessageIdentifier>)

    /// A server extension result option not defined in this library.
    ///
    /// This case captures future ESEARCH result data defined by extensions, allowing
    /// forward compatibility with new IMAP capabilities without requiring library updates.
    case dataExtension(KeyValue<String, ParameterValue>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnData(_ data: SearchReturnData) -> Int {
        switch data {
        case .min(let num):
            return self.writeString("MIN \(num)")
        case .max(let num):
            return self.writeString("MAX \(num)")
        case .all(let set):
            return
                self.writeString("ALL ") + self.writeLastCommandSet(set)
        case .count(let num):
            return self.writeString("COUNT \(num)")
        case .partial(let range, let set):
            var count = self.writeString("PARTIAL (") + self.writePartialRange(range) + self.writeString(" ")
            if set.isEmpty {
                count += self.writeNil()
            } else {
                count += self.writeUIDSet(set)
            }
            return count + self.writeString(")")
        case .dataExtension(let optionExt):
            return self.writeSearchReturnDataExtension(optionExt)
        case .modificationSequence(let seq):
            return self.writeString("MODSEQ \(seq)")
        }
    }
}
