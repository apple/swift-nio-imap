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
public enum IRelativePath: Equatable {
    case list(IMessageList)
    case messageOrPartial(IMessageOrPartial)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIRelativePath(_ path: IRelativePath) -> Int {
        switch path {
        case .list(let list):
            return self.writeIMessageList(list)
        case .messageOrPartial(let data):
            return self.writeIMessageOrPartial(data)
        }
    }
}
