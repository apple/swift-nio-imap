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

public struct GmailLabel: RawRepresentable, Equatable {
    public var rawValue: ByteBuffer

    public init(rawValue: ByteBuffer) {
        self.rawValue = rawValue
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeGmailLabel(_ label: GmailLabel) -> Int {
        if label.rawValue.getInteger(at: label.rawValue.readerIndex) == UInt8(ascii: "\\") {
            var rawValue = label.rawValue
            return self.writeBuffer(&rawValue)
        } else {
            return self.writeIMAPString(label.rawValue)
        }
    }
}
