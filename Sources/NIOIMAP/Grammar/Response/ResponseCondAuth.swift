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

    @discardableResult mutating func writeResponseConditionalAuth(_ cond: IMAPCore.ResponseConditionalAuth) -> Int {
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
