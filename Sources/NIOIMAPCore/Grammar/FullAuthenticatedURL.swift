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

/// Similar to `AuthImapURL`, but with an additional field to help verify the URL authorization.
public struct FullAuthenticatedURL: Equatable {
    /// An IMAP url pointing to a remote message.
    public var networkMessagePath: NetworkMessagePath

    /// URL authentication details.
    public var authenticatedURL: AuthenticatedURL

    /// Creates a new `FullAuthenticatedURL`.
    /// - parameter networkMessagePath: An IMAP url pointing to a remote message.
    /// - parameter authenticatedURL: URL authentication details.
    public init(networkMessagePath: NetworkMessagePath, authenticatedURL: AuthenticatedURL) {
        self.networkMessagePath = networkMessagePath
        self.authenticatedURL = authenticatedURL
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLFull(_ data: FullAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.networkMessagePath) +
            self.writeIAuthenticatedURL(data.authenticatedURL)
    }
}
