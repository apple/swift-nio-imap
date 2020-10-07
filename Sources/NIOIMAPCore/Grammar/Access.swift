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

/// RFC 5092
public enum Access: Equatable {
    case submit(EncodedUser)
    case user(EncodedUser)
    case authUser
    case anonymous
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAccess(_ data: Access) -> Int {
        switch data {
        case .submit(let user):
            return self.writeString("submit+") + self.writeEncodedUser(user)
        case .user(let user):
            return self.writeString("user+") + self.writeEncodedUser(user)
        case .authUser:
            return self.writeString("authuser")
        case .anonymous:
            return self.writeString("anonymous")
        }
    }
}
