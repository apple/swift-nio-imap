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

/// RFC 5092
public struct INetworkPath: Equatable {
    public var server: IServer
    public var query: IPathQuery
    
    public init(server: IServer, query: IPathQuery) {
        self.server = server
        self.query = query
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeINetworkPath(_ path: INetworkPath) -> Int {
        self.writeString("//") +
            self.writeIServer(path.server) +
            self.writeIPathQuery(path.query)
    }
}
