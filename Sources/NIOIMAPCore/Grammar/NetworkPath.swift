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

/// Combines an IMAP server location with a command to be executed once a connection is made.
public struct NetworkPath: Hashable, Sendable {
    /// The server to connect to.
    public var server: IMAPServer

    /// The command to execute.
    public var command: URLCommand?

    /// Creates a new `NetworkPath`.
    /// - parameter server: The server to connect to.
    /// - parameter command: The command to execute.
    public init(server: IMAPServer, query: URLCommand?) {
        self.server = server
        self.command = query
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNetworkPath(_ path: NetworkPath) -> Int {
        self.writeString("//") +
            self.writeIMAPServer(path.server) +
            self.writeString("/") +
            self.writeIfExists(path.command) { command in
                self.writeURLCommand(command)
            }
    }
}
