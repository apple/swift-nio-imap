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

/// Allows a client to optionally send an initial response when authenticating to speed
/// up the process.
public enum InitialClientResponse: Equatable {
    
    /// No initial response
    case empty
    
    /// Data encoded as Base64
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
