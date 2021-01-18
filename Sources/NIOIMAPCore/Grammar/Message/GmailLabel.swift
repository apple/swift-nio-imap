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

/// GMail treats labels as folders.
public struct GmailLabel: Equatable {
    /// The label's raw value -  a sequence of bytes
    public let stringValue: ByteBuffer

    /// Creates a new GMail label from the given bytes.
    /// - parameter rawValue: The raw bytes to construct the label
    public init(_ stringValue: ByteBuffer) {
        self.stringValue = stringValue
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeGmailLabel(_ label: GmailLabel) -> Int {
        if label.stringValue.getInteger(at: label.stringValue.readerIndex) == UInt8(ascii: "\\") {
            var stringValue = label.stringValue
            return self.writeBuffer(&stringValue)
        } else {
            return self.writeIMAPString(label.stringValue)
        }
    }
}
