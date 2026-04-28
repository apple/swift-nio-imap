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

/// Options for the `GETMETADATA` command to control metadata retrieval (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// Metadata options allow clients to specify constraints on metadata retrieval, such as limiting
/// entry size or specifying the search depth. These options are optional and can be combined to refine
/// metadata queries. See [RFC 5464 Section 4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.2).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA (MAXSIZE 1024 DEPTH 1) "INBOX" "/shared/comment"
/// S: * METADATA "INBOX" ("/shared/comment" "Server comment")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The options `(MAXSIZE 1024 DEPTH 1)` are ``MetadataOption`` values that limit results to entries
/// with a maximum size of 1024 bytes and restrict the search to a depth of 1 level.
///
/// ## Related types
///
/// - See ``MetadataEntryName`` for metadata entry names
/// - See ``MetadataValue`` for metadata entry values
/// - See ``MetadataResponse`` for complete metadata responses
/// - See ``ScopeOption`` for metadata depth options
///
/// - SeeAlso: [RFC 5464 Section 4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.2)
public enum MetadataOption: Hashable, Sendable {
    /// Limit returned entry values to those with a maximum size in octets.
    ///
    /// The `MAXSIZE` option restricts metadata retrieval to entries whose values do not exceed the
    /// specified octet count. Larger entries are silently omitted from the response.
    /// From [RFC 5464 Section 4.2.1](https://datatracker.ietf.org/doc/html/rfc5464#section-4.2.1).
    case maxSize(Int)

    /// Limit the search depth for hierarchical metadata entries.
    ///
    /// The `DEPTH` option constrains metadata retrieval to entries within a specified depth.
    /// From [RFC 5464 Section 4.2.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.2.2).
    case scope(ScopeOption)

    /// Extension option for future metadata extensions.
    ///
    /// Serves as a catch-all for additional options defined in future IMAP extensions related to metadata.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataOption(_ option: MetadataOption) -> Int {
        switch option {
        case .maxSize(let num):
            return self.writeString("MAXSIZE \(num)")
        case .scope(let opt):
            return self.writeScopeOption(opt)
        case .other(let param):
            return self.writeParameter(param)
        }
    }

    @discardableResult mutating func writeMetadataOptions(_ array: [MetadataOption]) -> Int {
        self.writeArray(array) { element, buffer in
            buffer.writeMetadataOption(element)
        }
    }
}
