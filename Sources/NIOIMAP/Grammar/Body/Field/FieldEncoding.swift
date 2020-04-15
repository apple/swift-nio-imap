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

import NIO
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldEncoding(_ encoding: IMAPCore.Body.FieldEncoding) -> Int {
        switch encoding {
        case .bit7:
            return self.writeString(#""7BIT""#)
        case .bit8:
            return self.writeString(#""8BIT""#)
        case .binary:
            return self.writeString(#""BINARY""#)
        case .base64:
            return self.writeString(#""BASE64""#)
        case .quotedPrintable:
            return self.writeString(#""QUOTED-PRINTABLE""#)
        case .string(let string):
            return self.writeIMAPString(string)
        }
    }

}
