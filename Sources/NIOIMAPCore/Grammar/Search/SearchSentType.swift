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

// Dervied from `search-key`
public enum SearchSentType: Equatable {
    case before(Date)
    case on(Date)
    case since(Date)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchSentType(_ type: SearchSentType) -> Int {
        switch type {
        case .before(let date):
            return
                self.writeString("SENTBEFORE ") +
                self.writeDate(date)
        case .on(let date):
            return
                self.writeString("SENTON ") +
                self.writeDate(date)
        case .since(let date):
            return
                self.writeString("SENTSINCE ") +
                self.writeDate(date)
        }
    }
}
