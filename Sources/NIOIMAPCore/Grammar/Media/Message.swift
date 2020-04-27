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

extension NIOIMAP.Media {
    public enum Message: String, Equatable {
        case rfc822 = "RFC822"
        case global = "GLOBAL"
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeMediaMessage(_ message: NIOIMAP.Media.Message) -> Int {
        self.writeString("\"MESSAGE\" \"\(message.rawValue)\"")
    }
}
