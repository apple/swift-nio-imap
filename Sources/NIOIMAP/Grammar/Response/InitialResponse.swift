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

extension NIOIMAP {

    /// IMAPv4 `initial-response`
    public enum InitialResponse: Equatable {
        case equals
        case base64(Base64)
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeInitialResponse(_ response: NIOIMAP.InitialResponse) -> Int {
        switch response {
        case .equals:
            return self.writeString("=")
        case .base64(let base64):
            return self.writeBase64(base64)
        }
    }
    
}
