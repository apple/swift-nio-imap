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

// MARK: - NString

/// IMAPv4 `nstring`
public struct NString: Equatable {
    var buffer: ByteBuffer?

    public init(buffer: ByteBuffer) {
        self.buffer = buffer
    }
}

// MARK: - Conveniences

extension NString: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.buffer = nil
    }
}

extension NString: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.buffer = ByteBuffer(string: value)
    }
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeNString(_ string: NString) -> Int {
        if let string = string.buffer {
            return self.writeIMAPString(string)
        } else {
            return self.writeNil()
        }
    }
}
