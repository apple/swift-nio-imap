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

/// IMAPv4 `message-data`
/// One message attribute is guaranteed
public enum MessageData: Equatable {
    case expunge(Int)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageData(_ data: MessageData) -> Int {
        switch data {
        case .expunge(let number):
            return self.writeString("\(number) EXPUNGE")
        }
    }

    @discardableResult mutating func writeMessageDataEnd(_: MessageData) -> Int {
        self.writeString(")")
    }
}
