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

/// Metadata search depth for the `GETMETADATA` command.
///
/// The `ScopeOption` enum specifies how deep the server should search for metadata
/// entries when retrieving annotation data using the `GETMETADATA` command (RFC 5464
/// METADATA extension). This determines whether the response includes only the exact
/// entry, only immediate children, or all descendants.
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA INBOX "/private" DEPTH 1
/// S: * METADATA INBOX ("/private/comments" "draft ready")
/// S: * METADATA INBOX ("/private/author" "john.doe")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The `DEPTH 1` option is represented as `ScopeOption.one`, limiting results to
/// entries immediately below the specified entry.
///
/// - SeeAlso: [RFC 5464 Section 4.4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.2) (DEPTH Option)
/// - SeeAlso: ``Command/getMetadata(_:options:)``
public struct ScopeOption: Hashable, Sendable {
    /// No child entries are included in results.
    ///
    /// Returns only the exact entry specified in the `GETMETADATA` command. Does not
    /// include any entries below the specified entry in the annotation hierarchy.
    ///
    /// Corresponds to the `DEPTH 0` option in the protocol.
    ///
    /// - SeeAlso: [RFC 5464 Section 4.4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.2)
    public static let zero = Self(_backing: .zero)

    /// Only immediate child entries are included in results.
    ///
    /// Returns the exact entry and entries that are direct children of the specified
    /// entry, but not deeper descendants. For example, with entry `/private`, this
    /// returns `/private` and `/private/comments` but not `/private/comments/draft`.
    ///
    /// Corresponds to the `DEPTH 1` option in the protocol.
    ///
    /// - SeeAlso: [RFC 5464 Section 4.4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.2)
    public static let one = Self(_backing: .one)

    /// All descendant entries are included in results.
    ///
    /// Returns the exact entry and all entries below it at any depth in the annotation
    /// hierarchy. This produces the most comprehensive metadata results but may return
    /// large response sets.
    ///
    /// Corresponds to the `DEPTH INFINITY` option in the protocol.
    ///
    /// - SeeAlso: [RFC 5464 Section 4.4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.2)
    public static let infinity = Self(_backing: .infinity)

    enum _Backing: String {
        case zero = "0"
        case one = "1"
        case infinity
    }

    let _backing: _Backing
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeScopeOption(_ opt: ScopeOption) -> Int {
        self.writeString("DEPTH \(opt._backing.rawValue)")
    }
}
