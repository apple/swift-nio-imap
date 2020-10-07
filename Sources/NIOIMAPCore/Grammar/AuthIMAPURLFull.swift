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

/// RFC 5092
public struct AuthIMAPURLFull: Equatable {
    public var imapURL: AuthIMAPURL
    public var urlAuth: IURLAuth

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
