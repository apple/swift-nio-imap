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
public enum RelativeIMAPURL: Equatable {
    case networkPath(INetworkPath)
    case absolutePath(IAbsolutePath)
    case relativePath(IRelativePath)
    case empty
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeRelativeIMAPURL(_ url: RelativeIMAPURL) -> Int {
        switch url {
        case .networkPath(let path):
            return self.writeINetworkPath(path)
        case .absolutePath(let path):
            return self.writeIAbsolutePath(path)
        case .relativePath(let path):
            return self.writeIRelativePath(path)
        case .empty:
            return 0
        }
    }
}
