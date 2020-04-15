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

    @discardableResult mutating func writeMessageData(_ data: IMAPCore.MessageData) -> Int {
        switch data {
        case .expunge(let number):
            return self.writeString("\(number) EXPUNGE")
        case .fetch(let number):
            return
                self.writeString("\(number) FETCH (")
        }
    }
    
    @discardableResult mutating func writeMessageDataEnd(_ data: IMAPCore.MessageData) -> Int {
        return self.writeString(")")
    }

}
