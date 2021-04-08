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

/// A URL that specifies a server to connect to and a command to run once a connection has been established.
public struct IMAPURL: Equatable {
    /// The server to connect to.
    public var server: IMAPServer

    /// A command to execute once a connection to server has been made.
    public var command: URLCommand?

    /// Creates a new `IMAPURL`.
    /// - parameter server: The server to connect to.
    /// - parameter command: A command to execute once a connection to server has been made.
    public init(server: IMAPServer, query: URLCommand?) {
        self.server = server
        self.command = query
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMAPURL(_ url: IMAPURL) -> Int {
        self._writeString("imap://") +
            self.writeIMAPServer(url.server) +
            self._writeString("/") +
                        self.writeIfExists(url.command) { command in
                            self.writeURLCommand(command)
                        }
    }
}
