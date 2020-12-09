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

/// A URL that can be used to point directly at a message part on a specified IMAP server.
public struct AuthIMAPURL: Equatable {
    
    /// The server containing the message.
    public var server: IServer
    
    /// The unique URL of the message, and the part of interest.
    public var messagePart: IMessagePart

    // Creates a new `AuthIMAPURL`.
    /// - parameter server: The server containing the message.
    /// - parameter messagePart: The unique URL of the message, and the part of interest.
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
