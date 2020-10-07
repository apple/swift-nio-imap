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
public struct IServer: Equatable {
    public var userInfo: IUserInfo?
    public var host: String
    public var port: Int?

    public init(userInfo: IUserInfo? = nil, host: String, port: Int? = nil) {
        self.userInfo = userInfo
        self.host = host
        self.port = port
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIServer(_ server: IServer) -> Int {
        self.writeIfExists(server.userInfo) { userInfo in
            self.writeIUserInfo(userInfo) + self.writeString("@")
        } +
            self.writeString("\(server.host)") +
            self.writeIfExists(server.port, callback: { port in
                self.writeString(":\(port)")
        })
    }
}
