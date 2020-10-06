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
public struct AuthImapUrlFull: Equatable {
    public var imapUrl: AuthImapUrl
    public var urlAuth: IUrlAuth
    
    public init(imapUrl: AuthImapUrl, urlAuth: IUrlAuth) {
        self.imapUrl = imapUrl
        self.urlAuth = urlAuth
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthImapUrlFull(_ data: AuthImapUrlFull) -> Int {
        self.writeAuthImapUrl(data.imapUrl) +
            self.writeIUrlAuth(data.urlAuth)
    }
}
