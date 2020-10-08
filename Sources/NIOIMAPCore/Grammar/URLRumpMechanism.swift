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

/// RFC 4467
public struct URLRumpMechanism: Equatable {
    public var urlRump: ByteBuffer
    public var mechanism: UAuthMechanism

    public init(urlRump: ByteBuffer, mechanism: UAuthMechanism) {
        self.urlRump = urlRump
        self.mechanism = mechanism
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLRumpMechanism(_ data: URLRumpMechanism) -> Int {
        self.writeSpace() +
            self.writeIMAPString(data.urlRump) +
            self.writeSpace() +
            self.writeUAuthMechanism(data.mechanism)
    }
}
