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

/// A command that should be executed once a server has been successfully connected to.
public enum URLCommand: Hashable {
    /// Performs a `.select` or `.examine` command.
    case messageList(EncodedSearchQuery)

    /// Performs a `.fetch` command.
    case fetch(path: MessagePath, authenticatedURL: AuthenticatedURL?)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLCommand(_ ref: URLCommand) -> Int {
        switch ref {
        case .messageList(let list):
            return self.writeEncodedSearchQuery(list)
        case .fetch(path: let path, authenticatedURL: let authenticatedURL):
            return self.writeMessagePath(path) +
                self.writeIfExists(authenticatedURL) { authenticatedURL in
                    self.writeIAuthenticatedURL(authenticatedURL)
                }
        }
    }
}
