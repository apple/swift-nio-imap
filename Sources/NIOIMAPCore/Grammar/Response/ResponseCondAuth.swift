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

/// IMAPv4 `resp-cond-auth`
public enum ResponseConditionalAuth: Equatable {
    case ok(ResponseText)
    case preauth(ResponseText)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseConditionalAuth(_ cond: ResponseConditionalAuth) -> Int {
        switch cond {
        case .ok(let text):
            return
                self.writeString("OK ") +
                self.writeResponseText(text)
        case .preauth(let text):
            return
                self.writeString("PREAUTH ") +
                self.writeResponseText(text)
        }
    }
}
