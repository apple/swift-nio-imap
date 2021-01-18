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
    /// Represents the body transfer encoding as defined in MIME-IMB.
    /// Recommended reading: RFC 2045
    public struct Encoding: CustomStringConvertible, Equatable {
        /// Represents 7-bit encoding, octets with a value larger than 127 are forbidden.
        public static var sevenBit: Self { Self("7BIT") }

        /// Represents 8-bit encoding, octets may be in the range 1-255. *NUL* octets are forbidden.
        public static var eightBit: Self { Self("8BIT") }

        /// Represents binary data where octets of any value are allowed, including *NUL*
        public static var binary: Self { Self("BINARY") }

        /// Represents an arbitrary sequence of octets in a non-human-readable form.
        public static var base64: Self { Self("BASE64") }

        /// Represents octets that mostly are printable characters in the US-ASCII character set.
        public static var quotedPrintable: Self { Self("QUOTED-PRINTABLE") }

        /// The uppercased encoding name
        public let stringValue: String

        /// The uppercased encoding name
        public var description: String { stringValue }

        /// Creates a new `Encoding` representation. Note that the `stringValue` will be uppercased to make the type easily `Equatable`.
        /// - parameter stringValue: The string representation of the new `Encoding`. Will be upper-cased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.uppercased()
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyEncoding(_ encoding: BodyStructure.Encoding) -> Int {
        self.writeString("\"\(encoding.description)\"")
    }
}
