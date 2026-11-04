//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension ResponsePayload {
    /// The JMAP Session resource URL in a `JMAPACCESS` response
    /// ([RFC 9698](https://datatracker.ietf.org/doc/html/rfc9698)):
    /// ```
    /// resp-jmapaccess = "JMAPACCESS" SP quoted
    /// ```
    ///
    /// ## Validity
    ///
    /// The URL is absolute and `https` (JMAP, RFC 8620, is served over HTTPS), and its string
    /// form needs no escaping inside `quoted`. ``init(_:)`` returns `nil` for anything else.
    public struct JMAPAccessURL: Hashable, Sendable {
        let url: URL

        /// Creates a JMAP access URL, if `url` is a valid one.
        ///
        /// A relative URL is resolved against its base: `jmap` relative to
        /// `https://example.com/.well-known/` is `https://example.com/.well-known/jmap`.
        ///
        /// - parameter url: The URL, for example `https://example.com/.well-known/jmap`.
        /// - returns: A new URL, or `nil` if `url` is not an absolute `https` URL.
        public init?(_ url: URL) {
            let absolute = url.absoluteURL
            guard Self.isValid(absolute) else { return nil }
            self.url = absolute
        }

        private static let scheme = "https"

        /// Absolute `https`, with a host, and every byte of the string a `QUOTED-CHAR` that needs
        /// no escaping.
        private static func isValid(_ url: URL) -> Bool {
            guard url.scheme?.lowercased() == Self.scheme, url.host?.isEmpty == false else { return false }
            return url.absoluteString.utf8.allSatisfy(\.isQuotedChar)
        }
    }
}

extension URL {
    /// Creates a `URL` from a ``ResponsePayload/JMAPAccessURL``.
    ///
    /// - parameter other: The JMAP access URL to convert.
    public init(_ other: ResponsePayload.JMAPAccessURL) {
        self = other.url
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeJMAPAccessURL(_ url: ResponsePayload.JMAPAccessURL) -> Int {
        // Verbatim: validated to need no escaping.
        self.writeString("\"\(url.url.absoluteString)\"")
    }
}
