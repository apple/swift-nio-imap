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

/// IMAPv4 `continue-req`
public enum ContinueRequest: Equatable {
    case responseText(ResponseText)
    case base64(ByteBuffer)
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult public mutating func writeContinueRequest(_ data: ContinueRequest) -> Int {
        var buffer = EncodeBuffer(self, mode: .client)
        defer {
            self = buffer.nextChunk().bytes
        }
        var size = 0
        size += buffer.writeString("+ ")
        switch data {
        case .responseText(let text):
            size += buffer.writeResponseText(text)
        case .base64(let base64):
            size += buffer.writeBase64(base64)
        }
        size += buffer.writeString("\r\n")
        return size
    }
}
