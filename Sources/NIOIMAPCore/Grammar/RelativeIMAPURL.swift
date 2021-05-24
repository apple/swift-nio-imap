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

///
public enum RelativeIMAPURL: Equatable {
    /// Rarely used, typically it's better to use an absolute path
    case networkPath(NetworkPath)

    /// A path that can be used to connect without any additional information
    case absolutePath(AbsoluteMessagePath)

    /// References the "same" document, in this cases meaning the current server/mailbox.
    case empty
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeRelativeIMAPURL(_ url: RelativeIMAPURL) -> Int {
        switch url {
        case .networkPath(let path):
            return self.writeNetworkPath(path)
        case .absolutePath(let path):
            return self.writeAbsoluteMessagePath(path)
        case .empty:
            return 0
        }
    }
}
