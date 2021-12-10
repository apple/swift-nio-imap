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

import struct NIO.ByteBuffer

/// Associates an `RumpAuthenticatedURL` with a rump URL to use for authorization verification is required.
public struct RumpAuthenticatedURL: Hashable {
    /// An IMAP URL pointing to a message.
    public var authenticatedURL: NetworkMessagePath

    /// A rump URL used to validate access if needed.
    public var authenticatedURLRump: AuthenticatedURLRump

    /// Creates a new `RumpAuthenticatedURL`.
    /// - parameter authenticatedURL: An IMAP URL pointing to a message.
    /// - parameter authenticatedURLRump: A rump URL used to validate access if needed.
    public init(authenticatedURL: NetworkMessagePath, authenticatedURLRump: AuthenticatedURLRump) {
        self.authenticatedURL = authenticatedURL
        self.authenticatedURLRump = authenticatedURLRump
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLRump(_ data: RumpAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.authenticatedURL) +
            self.writeAuthenticatedURLRump(data.authenticatedURLRump)
    }
}
