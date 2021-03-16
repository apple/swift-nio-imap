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

/// A URL that specifies a server to connect to and a query to run once a connection has been established.
public struct IMAPURL: Equatable {
    /// The server to connect to.
    public var server: IMAPServer

    /// A query to execute once a connection to server has been made.
    public var query: IPathQuery

    /// Creates a new `IMAPURL`.
    /// - parameter server: The server to connect to.
    /// - parameter query: A query to execute once a connection to server has been made.
    public init(server: IMAPServer, query: IPathQuery) {
        self.server = server
        self.query = query
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMAPURL(_ url: IMAPURL) -> Int {
        self.writeString("imap://") +
            self.writeIMAPServer(url.server) +
            self.writeIPathQuery(url.query)
    }
}
