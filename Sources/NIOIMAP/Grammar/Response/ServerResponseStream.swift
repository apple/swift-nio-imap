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

    public enum ServerResponseStream: Equatable {
        case response(ServerResponse)
        case bytes(ByteBuffer)
    }

}

extension ByteBuffer {

    @discardableResult public mutating func writeServerResponseStream(_ stream: NIOIMAP.ServerResponseStream) -> Int {
        switch stream {
        case .response(let response):
            return self.writeServerResponse(response)
        case .bytes(let bytes):
            var copy = bytes
            return self.writeBuffer(&copy)
        }
    }

}
