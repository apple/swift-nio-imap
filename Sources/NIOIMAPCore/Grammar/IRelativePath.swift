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

/// Used to specify the type of URL, e.g. one that retrieves a list of messages, or just a single message.
public enum IRelativePath: Equatable {
    /// An IMAP URL referring to a list of messages.
    case list(EncodedSearchQuery)

    /// An IMAP URL referring to a specific message, and optionally a component of message.
    case messageOrPartial(IMessageOrPartial)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIRelativePath(_ path: IRelativePath) -> Int {
        switch path {
        case .list(let list):
            return self.writeEncodedSearchQuery(list)
        case .messageOrPartial(let data):
            return self.writeIMessageOrPartial(data)
        }
    }
}
