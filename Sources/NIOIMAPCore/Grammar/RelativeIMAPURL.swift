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

/// A relative IMAP URL that references a resource without complete server information.
///
/// Relative URLs (RFC 3986) provide alternative ways to reference IMAP resources without
/// always specifying the full server location. They are useful when the server context
/// is already known or can be determined from the base URL context.
///
/// ### URL Variants
///
/// Relative IMAP URLs support three forms:
///
/// 1. **Network Path** (`//server/command`): Specifies a different server but uses the same scheme
/// 2. **Absolute Path** (`/command`): Refers to a resource on the current server
/// 3. **Empty** (''): Refers to the current document
///
/// ### Examples
///
/// Network path to a different server:
/// ```
/// //other.example.com/INBOX/;uid=20
/// ```
/// Resolved against base `imap://base.example.com/`:
/// ```
/// imap://other.example.com/INBOX/;uid=20
/// ```
///
/// Absolute path on the current server:
/// ```
/// /INBOX/;uid=30
/// ```
/// Resolved against base `imap://user@example.com/`:
/// ```
/// imap://user@example.com/INBOX/;uid=30
/// ```
///
/// Empty reference (current document):
/// ```
/// (empty)
/// ```
/// Resolved against base `imap://user@example.com/INBOX/`:
/// ```
/// imap://user@example.com/INBOX/
/// ```
///
/// ## Related Types
///
/// - ``IMAPURL`` provides absolute URL specification
/// - ``NetworkPath`` represents network-accessible paths
/// - ``AbsoluteMessagePath`` represents absolute paths
/// - ``URLCommand`` specifies operations within paths
///
/// - SeeAlso: [RFC 3986 Section 3](https://datatracker.ietf.org/doc/html/rfc3986#section-3) - Hierarchical Identifiers
/// - SeeAlso: [RFC 3986 Section 5](https://datatracker.ietf.org/doc/html/rfc3986#section-5) - Reference Resolution
public enum RelativeIMAPURL: Hashable, Sendable {
    /// A network-accessible path with a different server authority.
    ///
    /// Used to reference a resource on a different server while maintaining the same scheme.
    /// The new server specification (from the ``NetworkPath``) overrides the base URL's authority.
    case networkPath(NetworkPath)

    /// An absolute path on the current server.
    ///
    /// Used to reference a resource at the root of the current server without repeating
    /// server information.
    case absolutePath(AbsoluteMessagePath)

    /// Empty reference to the current document.
    ///
    /// Resolves to the base URL itself.
    case empty
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeRelativeIMAPURL(_ url: RelativeIMAPURL) -> Int {
        switch url {
        case .networkPath(let path):
            return self.writeNetworkPath(path)
        case .absolutePath(let path):
            return self.writeAbsoluteMessagePath(path)
        case .empty:
            return 0
        }
    }
}
