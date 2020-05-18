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

// Dervied from `fetch-att`
public enum FetchType: Equatable {
    case all
    case full
    case fast
    case attributes([FetchAttribute])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchType(_ type: FetchType) -> Int {
        switch type {
        case .all:
            return self.writeString("ALL")
        case .full:
            return self.writeString("FULL")
        case .fast:
            return self.writeString("FAST")
        case .attributes(let atts):
            return self.writeFetchAttributeList(atts)
        }
    }
}
