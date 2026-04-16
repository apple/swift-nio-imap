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
import struct OrderedCollections.OrderedDictionary

extension BodyStructure {
    /// Common header fields present in all `BODY` structures (RFC 3501).
    ///
    /// The `Fields` structure contains the standard fields that appear in both single-part
    /// and multipart body structures: content type parameters, content ID, description,
    /// transfer encoding, and octet count.
    ///
    /// These fields are derived from MIME headers (`Content-Type`, `Content-Transfer-Encoding`,
    /// etc.) and are essential for understanding how to process each message part.
    ///
    /// ### Example
    ///
    /// From a single-part body structure:
    /// ```
    /// ("text" "plain" ("charset" "us-ascii") NIL "This is the message" "7bit" 3445 65)
    /// ```
    ///
    /// The parameters `("charset" "us-ascii")`, content ID `NIL`, description `"This is the message"`,
    /// encoding `"7bit"`, and octet count `3445` are all represented in ``Fields``.
    ///
    /// - SeeAlso: [RFC 3501 Section 2.6.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.6.3)
    /// - SeeAlso: [RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045)
    /// - SeeAlso: ``Singlepart``
    public struct Fields: Hashable, Sendable {
        /// Parameters from the `Content-Type` header as key/value pairs.
        ///
        /// For example, `Content-Type: text/plain; charset=us-ascii` would have
        /// parameters `{"charset": "us-ascii"}`. The order of parameters is preserved.
        public var parameters: OrderedDictionary<String, String>

        /// The content ID from the `Content-ID` header, if present.
        ///
        /// A unique identifier for this part (per RFC 2045), used in multipart/related
        /// messages for referencing parts by ID.
        public var id: String?

        /// The content description from the `Content-Description` header, if present.
        ///
        /// A human-readable description of the message part.
        public var contentDescription: String?

        /// The content transfer encoding from the `Content-Transfer-Encoding` header.
        ///
        /// Describes how the message part is encoded (e.g., `7bit`, `base64`, `quoted-printable`).
        public var encoding: Encoding?

        /// The size of the body part in octets (bytes).
        ///
        /// This is the size of the data in its encoded state (per the `encoding` field),
        /// before any decoding would be applied. Clients can use this to estimate download sizes.
        public var octetCount: Int

        /// Creates a new body fields structure.
        /// - parameter parameters: Content-Type parameters as an ordered dictionary
        /// - parameter id: The content ID from `Content-ID` header
        /// - parameter contentDescription: The content description from `Content-Description` header
        /// - parameter encoding: The content transfer encoding
        /// - parameter octetCount: The size in octets (bytes)
        public init(
            parameters: OrderedDictionary<String, String>,
            id: String?,
            contentDescription: String?,
            encoding: BodyStructure.Encoding?,
            octetCount: Int
        ) {
            self.parameters = parameters
            self.id = id
            self.contentDescription = contentDescription
            self.encoding = encoding
            self.octetCount = octetCount
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyFields(_ fields: BodyStructure.Fields) -> Int {
        self.writeBodyParameterPairs(fields.parameters) + self.writeSpace() + self.writeNString(fields.id)
            + self.writeSpace() + self.writeNString(fields.contentDescription) + self.writeSpace()
            + self.writeBodyEncoding(fields.encoding) + self.writeString(" \(fields.octetCount)")
    }
}
