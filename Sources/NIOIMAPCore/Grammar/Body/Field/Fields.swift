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
    /// Contains fields that are common across bodies of all types (*basic*, *message*, and *text*)
    public struct Fields: Hashable, Sendable {
        /// An array of *attribute/value* pairs
        public var parameters: OrderedDictionary<String, String>

        /// A string giving the content ID as defined in MIME-IMB
        public var id: String?

        /// A string giving the content description as defined in MIME-IMB
        public var contentDescription: String?

        /// The string giving the content transfer encoding as defined in MIME-IMB
        public var encoding: Encoding?

        /// The size of the body in octets. Note that this is in the encoded state, before any decoding takes place.
        public var octetCount: Int

        /// Creates a new body `Fields`
        /// - parameter parameters: An array of *attribute/value* pairs
        /// - parameter id: A string giving the content ID as defined in MIME-IMB
        /// - parameter description: A string giving the content description as defined in MIME-IMB
        /// - parameter encoding: The string giving the content transfer encoding as defined in MIME-IMB
        /// - parameter octetCount: The size of the body in octets. Note that this is in the encoded state, before any decoding takes place.
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
