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
    public enum FieldEncoding: Equatable {
        case sevenBit
        case eightBit
        case binary
        case base64
        case quotedPrintable
        case other(String)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFieldEncoding(_ encoding: NIOIMAP.BodyStructure.FieldEncoding) -> Int {
        switch encoding {
        case .sevenBit:
            return self.writeString(#""7BIT""#)
        case .eightBit:
            return self.writeString(#""8BIT""#)
        case .binary:
            return self.writeString(#""BINARY""#)
        case .base64:
            return self.writeString(#""BASE64""#)
        case .quotedPrintable:
            return self.writeString(#""QUOTED-PRINTABLE""#)
        case .other(let string):
            return self.writeIMAPString(string)
        }
    }
}
