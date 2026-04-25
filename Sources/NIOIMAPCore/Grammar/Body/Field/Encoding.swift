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
    /// Represents the MIME content transfer encoding of a message part.
    ///
    /// The content transfer encoding specifies how the body data is encoded for transmission, allowing
    /// conversion between different character sets and encodings. Each message part declares its transfer
    /// encoding so recipients can decode it correctly.
    ///
    /// Encoding values are case-insensitive and normalized to uppercase for comparison. The standard encodings
    /// are defined in [RFC 2045 Section 6](https://datatracker.ietf.org/doc/html/rfc2045#section-6).
    ///
    /// ### Examples
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE ("text" "plain" ("charset" "utf-8") NIL NIL "7bit" 150))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The `"7bit"` encoding in the wire format corresponds to the ``sevenBit`` static member.
    ///
    /// - SeeAlso: [RFC 2045 Section 6](https://datatracker.ietf.org/doc/html/rfc2045#section-6)
    public struct Encoding: CustomDebugStringConvertible, Hashable, Sendable {
        /// Represents `7BIT` encoding, where octets must have values from 0-127.
        ///
        /// This is the default encoding for simple ASCII text messages. Octets with a value larger than 127 are forbidden.
        public static var sevenBit: Self { Self("7BIT") }

        /// Represents `8BIT` encoding, where octets may be in the range 0-255.
        ///
        /// This encoding allows arbitrary 8-bit values but excludes NUL octets (value 0), making it suitable for
        /// extended ASCII and other single-byte character sets.
        public static var eightBit: Self { Self("8BIT") }

        /// Represents `BINARY` encoding, where arbitrary octets are allowed.
        ///
        /// This encoding places no restrictions on octet values, including NUL, and is used for arbitrary binary data.
        public static var binary: Self { Self("BINARY") }

        /// Represents `BASE64` encoding, where data is encoded using the base64 algorithm.
        ///
        /// This is a safe encoding for binary data and arbitrary character sets, though it increases message size
        /// by approximately 33% due to the encoding overhead.
        public static var base64: Self { Self("BASE64") }

        /// Represents `QUOTED-PRINTABLE` encoding, where mostly-printable characters remain readable.
        ///
        /// This encoding represents printable US-ASCII characters literally while encoding other bytes, making
        /// messages somewhat human-readable. It is less efficient than base64for binary data.
        public static var quotedPrintable: Self { Self("QUOTED-PRINTABLE") }

        /// The uppercased encoding name
        internal let stringValue: String

        /// The encoding as an uppercase string.
        ///
        /// - Returns: The encoding name in uppercase, for example `"7BIT"`, `"BASE64"`, or `"QUOTED-PRINTABLE"`.
        public var debugDescription: String { stringValue }

        /// Creates a new encoding from a string representation.
        ///
        /// The provided string is automatically uppercased to normalize the encoding value. This allows
        /// case-insensitive comparison between encoding values.
        ///
        /// - parameter stringValue: The encoding name as a string (for example, `"7bit"` or `"base64"`). Will be uppercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.uppercased()
        }
    }
}

extension String {
    public init(_ other: BodyStructure.Encoding) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyEncoding(_ encoding: BodyStructure.Encoding?) -> Int {
        guard let encoding = encoding else {
            return self.writeNil()
        }
        return self.writeString("\"\(encoding.stringValue)\"")
    }
}
