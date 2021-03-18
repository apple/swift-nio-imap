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
public struct AuthenticatedURL: Equatable {
    /// The server containing the message.
    public var server: IMAPServer

    /// The unique URL of the message, and the part of interest.
    public var messagePart: IMessagePart

    // Creates a new `AuthenticatedURL`.
    /// - parameter server: The server containing the message.
    /// - parameter messagePart: The unique URL of the message, and the part of interest.
    public init(server: IMAPServer, messagePart: IMessagePart) {
        self.server = server
        self.messagePart = messagePart
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeAuthenticatedURL(_ data: AuthenticatedURL) -> Int {
        self._writeString("imap://") +
            self.writeIMAPServer(data.server) +
            self._writeString("/") +
            self.writeIMessagePart(data.messagePart)
    }
}
