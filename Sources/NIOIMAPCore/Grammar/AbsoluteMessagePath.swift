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

/// An absolute IMAP path.
public struct AbsoluteMessagePath: Hashable {
    /// A command (including a URL) to execute.
    public var command: URLCommand?

    /// Creates a new `IAbsoluteURL`.
    /// - parameter command: A command (including a URL) to execute.
    public init(command: URLCommand?) {
        self.command = command
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAbsoluteMessagePath(_ path: AbsoluteMessagePath) -> Int {
        self.writeString("/") +
            self.writeIfExists(path.command) { command in
                self.writeURLCommand(command)
            }
    }
}
