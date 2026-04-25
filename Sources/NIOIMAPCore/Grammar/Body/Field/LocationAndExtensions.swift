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

extension BodyStructure {
    /// Content location URI and future extension fields for a message part.
    ///
    /// Pairs a content location URI (defined in [RFC 2557](https://datatracker.ietf.org/doc/html/rfc2557))
    /// with a list of future extension fields. The location provides a URI where the message part content can be
    /// retrieved, and extensions allow servers to add new fields without breaking existing clients.
    ///
    /// Both the location and extensions are optional fields in the body structure defined in
    /// [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2).
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE ("text" "html" NIL NIL NIL "7bit" 1024 30 NIL NIL NIL "https://example.com/part" 42))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The location `"https://example.com/part"` and extension value `42` correspond to a ``LocationAndExtensions``
    /// with ``location`` = `"https://example.com/part"` and ``extensions`` = `[.number(42)]`.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    /// - SeeAlso: [RFC 2557](https://datatracker.ietf.org/doc/html/rfc2557)
    /// - SeeAlso: ``BodyExtension``
    public struct LocationAndExtensions: Hashable, Sendable {
        /// Optional URI indicating where the message part content can be retrieved.
        ///
        /// Defined in [RFC 2557](https://datatracker.ietf.org/doc/html/rfc2557). When `nil`, no location is specified.
        public var location: String?

        /// Future extension fields not yet formally defined.
        ///
        /// Extensions allow servers to include additional fields in the body structure without breaking
        /// existing clients. These fields follow the ``BodyExtension`` format (strings or integers).
        /// New extension fields can be added in future IMAP specifications.
        public var extensions: [BodyExtension]

        /// Creates a location and extensions pairing.
        ///
        /// - parameter location: Optional URI where content can be retrieved.
        /// - parameter extensions: Array of extension fields (typically empty for current usage).
        public init(location: String?, extensions: [BodyExtension]) {
            self.location = location
            self.extensions = extensions
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyLocationAndExtensions(
        _ locationExtension: BodyStructure.LocationAndExtensions
    ) -> Int {
        self.writeSpace() + self.writeNString(locationExtension.location)
            + self.write(if: !locationExtension.extensions.isEmpty) {
                self.writeSpace() + self.writeBodyExtensions(locationExtension.extensions)
            }
    }
}
