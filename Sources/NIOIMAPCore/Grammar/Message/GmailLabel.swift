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
public struct GmailLabel: RawRepresentable, Equatable {
    /// The label's raw value -  a sequence of bytes
    public var rawValue: ByteBuffer

    /// Creates a new GMail label from the given bytes.
    /// - parameter rawValue: The raw bytes to construct the label
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
