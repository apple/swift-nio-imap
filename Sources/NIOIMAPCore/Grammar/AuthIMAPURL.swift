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
public struct AuthIMAPURL: Equatable {
    public var server: IServer
    public var messagePart: IMessagePart

    public init(server: IServer, messagePart: IMessagePart) {
        self.server = server
        self.messagePart = messagePart
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURL(_ data: AuthIMAPURL) -> Int {
        self.writeString("imap://") +
            self.writeIServer(data.server) +
            self.writeString("/") +
            self.writeIMessagePart(data.messagePart)
    }
}
