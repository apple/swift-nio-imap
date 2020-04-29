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
    public struct FieldEncoding: CustomStringConvertible, Equatable {
        
        public typealias StringLiteralType = String
        
        public static var sevenBit: Self { return Self("7BIT") }
        public static var eightBit: Self { return Self("8BIT") }
        public static var binary: Self { return Self("BINARY") }
        public static var base64: Self { return Self("BASE64") }
        public static var quotedPrintable: Self { return Self("QUOTED-PRINTABLE") }
        
        public var description: String
        
        public init(_ rawValue: String) {
            self.description = rawValue
        }
        
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFieldEncoding(_ encoding: NIOIMAP.BodyStructure.FieldEncoding) -> Int {
        self.writeString("\"\(encoding.description)\"")
    }
}
