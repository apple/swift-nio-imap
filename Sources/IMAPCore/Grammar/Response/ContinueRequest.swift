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

extension IMAPCore {

    /// IMAPv4 `continue-req`
    public enum ContinueRequest: Equatable {
        case responseText(ResponseText)
        case base64([UInt8])
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeContinueRequest(_ data: IMAPCore.ContinueRequest) -> Int {
        var size = 0
        size += self.writeString("+ ")
        switch data {
        case .responseText(let text):
            size += self.writeResponseText(text)
        case .base64(let base64):
            size += self.writeBytes(base64)
        }
        size += self.writeString("\r\n")
        return size
    }

}
