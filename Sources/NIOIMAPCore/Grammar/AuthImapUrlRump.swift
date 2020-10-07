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
public struct AuthImapUrlRump: Equatable {
    public var imapUrl: AuthImapUrl
    public var authRump: IURLAuthRump

    public init(imapUrl: AuthImapUrl, authRump: IURLAuthRump) {
        self.imapUrl = imapUrl
        self.authRump = authRump
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthImapUrlRump(_ data: AuthImapUrlRump) -> Int {
        self.writeAuthImapUrl(data.imapUrl) +
            self.writeIURLAuthRump(data.authRump)
    }
}
