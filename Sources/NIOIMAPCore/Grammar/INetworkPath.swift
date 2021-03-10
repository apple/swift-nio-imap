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

/// Combines an IMAP server location with a query to be executed once a connection is made.
public struct INetworkPath: Equatable {
    /// The server to connect to.
    public var server: IMAPServer

    /// The query to execute.
    public var query: IPathQuery

    /// Creates a new `INetworkPath`.
    /// - parameter server: The server to connect to.
    /// - parameter query: The query to execute.
    public init(server: IMAPServer, query: IPathQuery) {
        self.server = server
        self.query = query
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeINetworkPath(_ path: INetworkPath) -> Int {
        self.writeString("//") +
            self.writeIMAPServer(path.server) +
            self.writeIPathQuery(path.query)
    }
}
