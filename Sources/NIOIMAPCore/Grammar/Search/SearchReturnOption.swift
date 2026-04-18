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

/// A result option for the `SEARCH` command's extended `RETURN` clause (RFC 4731 ESEARCH extension).
///
/// The ESEARCH extension allows clients to control what kind of information is returned from a search operation,
/// enabling more efficient searching by allowing the server to return only the data the client needs.
///
/// **Requires server capability:** ``Capability/extendedSearch``
///
/// When one or more result options are specified in the `RETURN` clause of a `SEARCH` or `UID SEARCH` command,
/// the server responds with an ESEARCH response (see ``ExtendedSearchResponse``) instead of a standard search response.
///
/// ### Examples
///
/// ```
/// C: A001 SEARCH RETURN (MIN COUNT) FLAGGED
/// S: * ESEARCH (TAG "A001") MIN 2 COUNT 3
/// S: A001 OK SEARCH completed
/// ```
///
/// The `RETURN (MIN COUNT)` clause is represented by `[.min, .count]`. The server's response data
/// is wrapped as ``SearchReturnData/min(_:)`` and ``SearchReturnData/count(_:)`` cases.
///
/// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
public enum SearchReturnOption: Hashable, Sendable {
    /// Return the lowest message number/UID that satisfies the search criteria.
    ///
    /// If the search returns no matches, the server MUST NOT include this option in the response.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case min

    /// Return the highest message number/UID that satisfies the search criteria.
    ///
    /// If the search returns no matches, the server MUST NOT include this option in the response.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case max

    /// Return all message numbers/UIDs that satisfies the search criteria in sequence-set syntax.
    ///
    /// Unlike standard `SEARCH` responses which use space-separated lists, results are returned
    /// as a compact sequence-set representation (e.g., `2,10:11`) that can be used directly
    /// in subsequent commands. If the search returns no matches, the server MUST NOT include
    /// this option in the response.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case all

    /// Return the count of messages that satisfy the search criteria.
    ///
    /// Unlike other result options, this option MUST always be included in the ESEARCH response,
    /// even when the count is zero.
    ///
    /// - SeeAlso: [RFC 4731 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4731#section-3.1)
    case count

    /// Request that the server remember the search result for use with the `$` command.
    ///
    /// Tells the server to store the result of the `SEARCH`, `UID SEARCH`, `SORT`, or `THREAD` command
    /// so that the result set can be referenced as `$` in subsequent commands. Only one search result
    /// can be active at a time; a new search result replaces the previous one.
    ///
    /// - SeeAlso: [RFC 5182](https://datatracker.ietf.org/doc/html/rfc5182)
    case save

    /// Request a subset of the results using pagination.
    ///
    /// This option is part of the PARTIAL extension for paginated search results. When specified,
    /// the server returns only the requested range of matching messages rather than all results,
    /// reducing bandwidth and server processing time.
    ///
    /// - SeeAlso: [RFC 9394](https://datatracker.ietf.org/doc/html/rfc9394)
    case partial(PartialRange)

    /// A server extension result option not defined in this library.
    ///
    /// This case captures future ESEARCH result options defined by extensions, allowing
    /// forward compatibility with new IMAP capabilities without requiring library updates.
    case optionExtension(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnOption(_ option: SearchReturnOption) -> Int {
        switch option {
        case .min:
            return self.writeString("MIN")
        case .max:
            return self.writeString("MAX")
        case .all:
            return self.writeString("ALL")
        case .count:
            return self.writeString("COUNT")
        case .save:
            return self.writeString("SAVE")
        case .partial(let range):
            return self.writeString("PARTIAL ") + self.writePartialRange(range)
        case .optionExtension(let option):
            return self.writeSearchReturnOptionExtension(option)
        }
    }

    @discardableResult mutating func writeSearchReturnOptions(_ options: [SearchReturnOption]) -> Int {
        guard options.count > 0 else {
            return 0
        }
        // When `options == [.all]`, we _could_ encode this as
        // `RETURN ()` according to RFC 7377, but many esoteric
        // servers will fail to parse this correctly.
        return
            self.writeString(" RETURN (")
            + self.writeIfExists(options) { (options) -> Int in
                self.writeArray(options, parenthesis: false) { (option, self) in
                    self.writeSearchReturnOption(option)
                }
            } + self.writeString(")")
    }
}
