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
    /// Recomended reading: RFC 2045
    public struct Encoding: RawRepresentable, CustomStringConvertible, Equatable {
        /// The uppercased encoding name
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue.uppercased()
        }

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

        /// See `rawValue`.
        public var description: String {
            rawValue
        }

        /// Creates a new type with the given `String`.
        /// - Note: the `String` will be uppercased.
        public init(_ rawValue: String) {
            self.init(rawValue: rawValue)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyEncoding(_ encoding: BodyStructure.Encoding) -> Int {
        self.writeString("\"\(encoding.description)\"")
    }
}
