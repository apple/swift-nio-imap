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
public struct EncodedAuthenticationType: Equatable {
    public var authType: String
    
    public init(authType: String) {
        self.authType = authType
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedAuthenticationType(_ type: EncodedAuthenticationType) -> Int {
        self.writeString(type.authType)
    }
}
