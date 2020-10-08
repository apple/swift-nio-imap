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

// RFC 4467
public struct MechanismBase64: Equatable {
    public var mechanism: UAuthMechanism
    public var base64: ByteBuffer?

    public init(mechanism: UAuthMechanism, base64: ByteBuffer?) {
        self.mechanism = mechanism
        self.base64 = base64
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMechanismBase64(_ data: MechanismBase64) -> Int {
        self.writeUAuthMechanism(data.mechanism) +
            self.writeIfExists(data.base64, callback: { base64 in
                self.writeString("=") +
                    self.writeBuffer(&base64)
            })
    }
}
