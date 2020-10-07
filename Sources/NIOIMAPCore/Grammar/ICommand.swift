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
public enum ICommand: Equatable {
    case messageList(IMessageList)
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
                self.writeIfExists(urlAuth, callback: { urlAuth in
                    self.writeIURLAuth(urlAuth)
                })
        }
    }
}
