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
    /// An IMAP url pointing to a message.
    public var imapURL: AuthenticatedURL

    /// URL authentication details.
    public var authenticatedURL: IAuthenticatedURL

    /// Creates a new `AuthIMAPURL`.
    /// - parameter imapURL: An IMAP url pointing to a message.
    /// - parameter authenticatedURL: URL authentication details.
    public init(imapURL: AuthenticatedURL, authenticatedURL: IAuthenticatedURL) {
        self.imapURL = imapURL
        self.authenticatedURL = authenticatedURL
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLFull(_ data: FullAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.imapURL) +
            self.writeIAuthenticatedURL(data.authenticatedURL)
    }
}
