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

/// Associates an `AuthIMAPURL` with a rump URL to use for authorization verification is required.
public struct RumpAuthenticatedURL: Equatable {
    /// An IMAP URL pointing to a message.
    public var authenticatedURL: AuthenticatedURL

    /// A rump URL used to validate access if needed.
    public var authenticatedURLRump: IRumpAuthenticatedURL

    /// Creates a new `AuthIMAPURLRump`.
    /// - parameter imapURL: An IMAP URL pointing to a message.
    /// - parameter authenticatedURLRump: A rump URL used to validate access if needed.
    public init(authenticatedURL: AuthenticatedURL, authenticatedURLRump: IRumpAuthenticatedURL) {
        self.authenticatedURL = authenticatedURL
        self.authenticatedURLRump = authenticatedURLRump
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLRump(_ data: RumpAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.authenticatedURL) +
            self.writeIRumpAuthenticatedURL(data.authenticatedURLRump)
    }
}
