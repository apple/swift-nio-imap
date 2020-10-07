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
public struct AuthIMAPURLRump: Equatable {
    public var imapUrl: AuthIMAPURL
    public var authRump: IURLAuthRump

    public init(imapUrl: AuthIMAPURL, authRump: IURLAuthRump) {
        self.imapUrl = imapUrl
        self.authRump = authRump
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLRump(_ data: AuthIMAPURLRump) -> Int {
        self.writeAuthIMAPURL(data.imapUrl) +
            self.writeIURLAuthRump(data.authRump)
    }
}