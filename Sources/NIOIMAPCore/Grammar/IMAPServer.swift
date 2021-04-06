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

/// Represents an IMAP connection configuration that be used to connect
/// to an IMAP server.
public struct IMAPServer: Equatable {
    /// If present, authentication details for the server.
    public var userAuthenticationMechanism: UserAuthenticationMechanism?

    /// The hostname of the server.
    public var host: String

    /// The host port of the server.
    public var port: Int?

    /// Creates a new `IMAPServer`.
    /// - parameter userAuthenticationMechanism: If present, authentication details for the server. Defaults to `nil`.
    /// - parameter host: The hostname of the server.
    /// - parameter port: The host post of the server. Defaults to `nil`.
    public init(userAuthenticationMechanism: UserAuthenticationMechanism? = nil, host: String, port: Int? = nil) {
        self.userAuthenticationMechanism = userAuthenticationMechanism
        self.host = host
        self.port = port
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMAPServer(_ server: IMAPServer) -> Int {
        self.writeIfExists(server.userAuthenticationMechanism) { authMechanism in
            self.writeUserAuthenticationMechanism(authMechanism) + self._writeString("@")
        } +
            self._writeString("\(server.host)") +
            self.writeIfExists(server.port) { port in
                self._writeString(":\(port)")
            }
    }
}
