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
    /// IMAPv4 `body-fld-enc`
    public struct Encoding: RawRepresentable, CustomStringConvertible, Equatable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue.uppercased()
        }

        public static var sevenBit: Self { Self("7BIT") }
        public static var eightBit: Self { Self("8BIT") }
        public static var binary: Self { Self("BINARY") }
        public static var base64: Self { Self("BASE64") }
        public static var quotedPrintable: Self { Self("QUOTED-PRINTABLE") }

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
