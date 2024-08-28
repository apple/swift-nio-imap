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
    public struct DispositionKind: Hashable, RawRepresentable, Sendable {
        public static let inline = Self(rawValue: "inline")
        public static let attachment = Self(rawValue: "attachment")

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }
    }

    /// A parsed representation of a parenthesized list containing a type string, and attribute/value pairs.
    /// Recomended reading: RFC 3501 § 7.4.2 and RFC 2183
    public struct Disposition: Hashable {
        /// The disposition type string.
        public var kind: DispositionKind

        /// An array of *attribute/value* pairs.
        public var parameters: OrderedDictionary<String, String>

        /// Creates a new `Disposition`
        /// - parameter kind: A string representing the disposition type.
        /// - parameter parameters: An array of *attribute/value* pairs.
        public init(kind: DispositionKind, parameters: OrderedDictionary<String, String>) {
            self.kind = kind
            self.parameters = parameters
        }

        /// Attempts to find and convert the value for the common field "SIZE". If the field doesn't exist or is not a valid integer then `nil` is returned.
        public var size: Int? {
            guard let value = self.parameters.first(where: { (pair) -> Bool in
                pair.0.lowercased() == "size"
            })?.1 else {
                return nil
            }
            return Int(value)
        }

        /// Attempts to find and convert the value for the common field "SIZE". If the field doesn't exist then `nil` is returned.
        public var filename: String? {
            self.parameters.first(where: { (pair) -> Bool in
                pair.0.lowercased() == "filename"
            })?.1
        }
    }
}

extension BodyStructure.DispositionKind: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value.lowercased()
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyDisposition(_ dsp: BodyStructure.Disposition?) -> Int {
        guard let dsp = dsp else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeIMAPString(dsp.kind.rawValue) +
            self.writeSpace() +
            self.writeBodyParameterPairs(dsp.parameters) +
            self.writeString(")")
    }
}
