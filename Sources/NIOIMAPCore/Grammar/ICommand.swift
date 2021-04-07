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
public enum ICommand: Equatable {
    /// Performs a `.select` or `.examine` command.
    case messageList(EncodedSearchQuery)

    /// Performs a `.fetch` command.
    case messagePart(part: MessagePath, authenticatedURL: IAuthenticatedURL?)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeICommand(_ ref: ICommand) -> Int {
        switch ref {
        case .messageList(let list):
            return self.writeEncodedSearchQuery(list)
        case .messagePart(part: let path, authenticatedURL: let authenticatedURL):
            return self.writeMessagePath(path) +
                self.writeIfExists(authenticatedURL) { authenticatedURL in
                    self.writeIAuthenticatedURL(authenticatedURL)
                }
        }
    }
}
