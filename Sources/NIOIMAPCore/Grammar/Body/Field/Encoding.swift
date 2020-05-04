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

extension NIOIMAP.BodyStructure {
    /// IMAPv4 `body-fld-enc`
    public struct Encoding: CustomStringConvertible, Equatable {
        public typealias StringLiteralType = String

        public static var sevenBit: Self { Self("7BIT") }
        public static var eightBit: Self { Self("8BIT") }
        public static var binary: Self { Self("BINARY") }
        public static var base64: Self { Self("BASE64") }
        public static var quotedPrintable: Self { Self("QUOTED-PRINTABLE") }

        public var description: String

        public init(_ rawValue: String) {
            self.description = rawValue
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyEncoding(_ encoding: NIOIMAP.BodyStructure.Encoding) -> Int {
        self.writeString("\"\(encoding.description)\"")
    }
}
