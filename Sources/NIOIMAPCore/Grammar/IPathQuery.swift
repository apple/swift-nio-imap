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

/// Wraps a command to be executed on a a server once a connection has been established.
public struct IPathQuery: Equatable {
    /// A command to execute.
    public var command: ICommand?

    /// Creates a new `IPathQuery`
    /// - parameter command: The command to execute.
    public init(command: ICommand?) {
        self.command = command
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIPathQuery(_ query: IPathQuery) -> Int {
        self.writeString("/") +
            self.writeIfExists(query.command) { command in
                self.writeICommand(command)
            }
    }
}
