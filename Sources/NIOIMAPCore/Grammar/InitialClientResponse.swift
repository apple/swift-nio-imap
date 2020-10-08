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

/// RFC 4959
public enum InitialClientResponse: Equatable {
    case empty
    case data(ByteBuffer)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInitialClientResponse(_ resp: InitialClientResponse) -> Int {
        switch resp {
        case .empty:
            return self.writeString("=")
        case .data(var buffer):
            return self.writeBuffer(&buffer)
        }
    }
}
