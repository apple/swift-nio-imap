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
    case messageList(IMessageList)

    /// Performs a `.fetch` command.
    case messagePart(part: IMessagePart, urlAuth: IURLAuth?)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeICommand(_ ref: ICommand) -> Int {
        switch ref {
        case .messageList(let list):
            return self.writeIMessageList(list)
        case .messagePart(part: let part, urlAuth: let urlAuth):
            return self.writeIMessagePart(part) +
                self.writeIfExists(urlAuth) { urlAuth in
                    self.writeIURLAuth(urlAuth)
                }
        }
    }
}
