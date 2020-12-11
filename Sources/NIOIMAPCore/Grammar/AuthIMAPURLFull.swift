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
public struct AuthIMAPURLFull: Equatable {
    /// An IMAP url pointing to a message.
    public var imapURL: AuthIMAPURL

    /// URL authentication details.
    public var urlAuth: IURLAuth

    /// Creates a new `AuthIMAPURL`.
    /// - parameter imapURL: An IMAP url pointing to a message.
    /// - parameter urlAuth: URL authentication details.
    public init(imapURL: AuthIMAPURL, urlAuth: IURLAuth) {
        self.imapURL = imapURL
        self.urlAuth = urlAuth
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLFull(_ data: AuthIMAPURLFull) -> Int {
        self.writeAuthIMAPURL(data.imapURL) +
            self.writeIURLAuth(data.urlAuth)
    }
}
